# frozen_string_literal: true

module Alerts
  class Engine
    EVALUATOR_MAP = {
      Alert::PRICE_TYPES => "Alerts::PriceEvaluator",
      Alert::VOLUME_TYPES => "Alerts::VolumeEvaluator",
      Alert::TECHNICAL_TYPES => "Alerts::TechnicalEvaluator",
      Alert::NEWS_TYPES => "Alerts::NewsEvaluator"
    }.freeze

    ALERT_CACHE_TTL = 30
    DEDUP_TTL = 300
    QUIET_HOURS_QUEUE_KEY = "alerts:quiet_hours_queue"

    def evaluate(aggregated_price)
      symbol = aggregated_price[:symbol]
      return unless symbol

      alerts = cached_alerts_for(symbol)
      return if alerts.empty?

      alerts.each do |alert|
        evaluate_single(alert, aggregated_price)
      rescue StandardError => e
        Rails.logger.error("[AlertEngine] Error evaluating alert #{alert.id}: #{e.message}")
      end
    end

    # For news alerts called by CheckNewsJob
    def evaluate_news(alert, news_item)
      result = Alerts::NewsEvaluator.new.evaluate(alert, news_data: news_item)
      return unless result&.dig(:triggered)

      process_trigger(alert, result, news_item)
    end

    private

    def evaluate_single(alert, aggregated_price)
      evaluator = evaluator_for(alert)
      return unless evaluator

      result = evaluator.evaluate(alert, price_data: aggregated_price)
      return unless result&.dig(:triggered)

      process_trigger(alert, result, aggregated_price)
    end

    def process_trigger(alert, result, context_data)
      user = alert.user

      allowed, reason = run_anti_spam_checks(alert, user, result)

      unless allowed
        log_decision(alert, "blocked", reason)
        return
      end

      alert.record_trigger!
      history = create_alert_history(alert, user, result, context_data)
      enqueue_notification(alert, user, result, history)
      request_ai_analysis(alert, result, context_data) if alert.ai_analysis_enabled

      log_decision(alert, "triggered", "all checks passed")
    end

    # --- Evaluator Routing ---

    def evaluator_for(alert)
      EVALUATOR_MAP.each do |types, class_name|
        return class_name.constantize.new if types.include?(alert.alert_type)
      end
      nil
    end

    # --- Alert Cache ---

    def cached_alerts_for(symbol)
      cache_key = "alerts:enabled:#{symbol.upcase}"

      cached_ids = REDIS_POOL.with { |r| r.get(cache_key) }
      if cached_ids
        ids = JSON.parse(cached_ids)
        return Alert.where(id: ids).includes(:user)
      end

      alerts = Alert.enabled.for_symbol(symbol).includes(:user).to_a
      REDIS_POOL.with do |r|
        r.setex(cache_key, ALERT_CACHE_TTL, alerts.map(&:id).to_json)
      end
      alerts
    end

    # --- Anti-Spam Checks ---

    def run_anti_spam_checks(alert, user, result)
      checks = [
        check_mute(user),
        check_cooldown(alert),
        check_rate_limit(user),
        check_dedup(alert, result),
        check_quiet_hours(alert, user, result)
      ]

      checks.each do |allowed, reason|
        return [ false, reason ] unless allowed
      end

      [ true, nil ]
    end

    def check_mute(user)
      if user.muted?
        [ false, "user muted until #{user.muted_until}" ]
      else
        [ true, nil ]
      end
    end

    def check_cooldown(alert)
      if alert.in_cooldown?
        [ false, "cooldown active (#{alert.cooldown_minutes}min)" ]
      else
        [ true, nil ]
      end
    end

    def check_rate_limit(user)
      max_per_min = ENV.fetch("ALERT_MAX_PER_MINUTE_PER_USER", 10).to_i
      key = "user_alerts:#{user.id}:#{Time.current.strftime('%Y%m%d%H%M')}"

      count = REDIS_POOL.with do |redis|
        current = redis.incr(key)
        redis.expire(key, 120) if current == 1
        current
      end

      if count > max_per_min
        [ false, "rate limit exceeded (#{count}/#{max_per_min} per minute)" ]
      else
        [ true, nil ]
      end
    end

    def check_dedup(alert, result)
      trigger_hash = Digest::SHA256.hexdigest(result.except(:triggered).to_json)
      key = "alert_dedup:#{alert.id}:#{trigger_hash}"

      already_sent = REDIS_POOL.with do |redis|
        # SET NX is atomic — returns true only if key was newly set
        !redis.set(key, "1", ex: DEDUP_TTL, nx: true)
      end

      if already_sent
        [ false, "duplicate trigger within #{DEDUP_TTL}s" ]
      else
        [ true, nil ]
      end
    end

    def check_quiet_hours(alert, user, result)
      if user.in_quiet_hours?
        queue_for_after_quiet_hours(alert, user, result)
        [ false, "quiet hours — queued for later delivery" ]
      else
        [ true, nil ]
      end
    end

    def queue_for_after_quiet_hours(alert, user, result)
      prefs = user.notification_preferences&.deep_symbolize_keys || {}
      tz = ActiveSupport::TimeZone[user.timezone] || ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
      now = Time.current.in_time_zone(tz)

      # Find earliest quiet_end across enabled channels
      quiet_end_time = user.enabled_channels.filter_map do |channel|
        channel_prefs = prefs[channel] || {}
        next unless channel_prefs[:quiet_end]

        hour, min = channel_prefs[:quiet_end].split(":").map(&:to_i)
        end_time = tz.local(now.year, now.month, now.day, hour, min)
        end_time += 1.day if end_time <= now
        end_time
      end.min

      return unless quiet_end_time

      payload = { alert_id: alert.id, user_id: user.id, result: result }.to_json
      REDIS_POOL.with do |redis|
        redis.zadd(QUIET_HOURS_QUEUE_KEY, quiet_end_time.to_f, payload)
      end
    end

    # --- Trigger Actions ---

    def create_alert_history(alert, user, result, context_data)
      AlertHistory.create!(
        alert: alert,
        user: user,
        symbol: alert.symbol,
        alert_type: alert.alert_type,
        triggered_at: Time.current,
        price_at_trigger: context_data[:close] || context_data[:price] || 0,
        previous_price: result[:previous_price],
        change_percent: context_data[:change_percent],
        volume_at_trigger: context_data[:volume],
        indicator_values: result[:indicator_values],
        condition_snapshot: alert.condition,
        notification_results: {}
      )
    end

    def enqueue_notification(alert, user, _result, context_data)
      SendNotificationJob.perform_later(
        user_id: user.id,
        alert_id: alert.id,
        aggregated_price: context_data
      )
    end

    def request_ai_analysis(alert, result, context_data)
      AiServiceClient.new.evaluate_importance(
        alert_type: alert.alert_type,
        symbol: alert.symbol,
        alert_description: result[:message] || alert.notes,
        current_context: {
          price: context_data[:close],
          change_percent: context_data[:change_percent],
          volume: context_data[:volume]
        }
      )
    rescue StandardError => e
      Rails.logger.warn("[AlertEngine] AI analysis failed for alert #{alert.id}: #{e.message}")
    end

    # --- Logging ---

    def log_decision(alert, status, reason)
      Rails.logger.info(
        "[AlertEngine] alert_id=#{alert.id} symbol=#{alert.symbol} " \
        "type=#{alert.alert_type} status=#{status} reason=#{reason}"
      )
    end
  end
end
