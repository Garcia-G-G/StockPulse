# frozen_string_literal: true

module Alerts
  class PriceEvaluator
    def evaluate(alert, price_data:, **_opts)
      current_price = price_data[:close]&.to_f
      return unless current_price&.positive?

      condition = alert.condition.deep_symbolize_keys
      last_price = read_last_price(alert.id)
      store_last_price(alert.id, current_price)

      result = case alert.alert_type
      when "price_above" then evaluate_price_above(current_price, last_price, condition)
      when "price_below" then evaluate_price_below(current_price, last_price, condition)
      when "percent_change_up" then evaluate_percent_change(alert, price_data, condition, :up)
      when "percent_change_down" then evaluate_percent_change(alert, price_data, condition, :down)
      when "price_range_break" then evaluate_range_break(current_price, last_price, condition)
      end

      result
    end

    private

    # --- Price Above/Below (crossing detection) ---

    def evaluate_price_above(current, last, condition)
      target = condition[:target_price]&.to_f
      return unless target&.positive?
      return unless last && last < target && current >= target

      {
        triggered: true,
        message: "Price crossed above $#{target} (now $#{current})",
        previous_price: last
      }
    end

    def evaluate_price_below(current, last, condition)
      target = condition[:target_price]&.to_f
      return unless target&.positive?
      return unless last && last > target && current <= target

      {
        triggered: true,
        message: "Price crossed below $#{target} (now $#{current})",
        previous_price: last
      }
    end

    # --- Percent Change ---

    def evaluate_percent_change(alert, price_data, condition, direction)
      threshold = condition[:threshold_percent]&.to_f
      timeframe = condition[:timeframe]&.to_s
      return unless threshold&.positive?

      reference_price = reference_price_for(alert.symbol, timeframe, price_data)
      return unless reference_price&.positive?

      current = price_data[:close].to_f
      pct_change = ((current - reference_price) / reference_price * 100).round(4)

      triggered = case direction
      when :up then pct_change >= threshold
      when :down then pct_change <= -threshold
      end

      return unless triggered

      {
        triggered: true,
        message: "#{alert.symbol} moved #{pct_change > 0 ? '+' : ''}#{pct_change}% (threshold: #{direction == :up ? '+' : '-'}#{threshold}%)",
        previous_price: reference_price,
        indicator_values: { percent_change: pct_change, timeframe: timeframe }
      }
    end

    def reference_price_for(symbol, timeframe, price_data)
      case timeframe
      when "1d"
        # Use previous close from price data or latest daily snapshot
        price_data[:previous_close] || latest_snapshot_close(symbol, "1d")
      when "1h"
        latest_snapshot_close(symbol, "1h", 1.hour.ago)
      when "4h"
        latest_snapshot_close(symbol, "1h", 4.hours.ago)
      when "15m"
        latest_snapshot_close(symbol, "15m", 15.minutes.ago)
      when "5m"
        latest_snapshot_close(symbol, "5m", 5.minutes.ago)
      end
    end

    def latest_snapshot_close(symbol, interval, since = nil)
      scope = PriceSnapshot.for_symbol(symbol).by_interval(interval).latest_first
      scope = scope.where(timestamp: since..) if since
      scope.first&.close_price&.to_f
    end

    # --- Range Break ---

    def evaluate_range_break(current, last, condition)
      lower = condition[:lower]&.to_f
      upper = condition[:upper]&.to_f
      return unless lower && upper && lower < upper
      return unless last

      was_inside = last >= lower && last <= upper
      now_outside = current < lower || current > upper

      return unless was_inside && now_outside

      direction = current > upper ? "above upper ($#{upper})" : "below lower ($#{lower})"
      {
        triggered: true,
        message: "Price broke #{direction} (now $#{current})",
        previous_price: last
      }
    end

    # --- Redis State ---

    def read_last_price(alert_id)
      REDIS_POOL.with { |r| r.get("alert_state:#{alert_id}:last_price")&.to_f }
    end

    def store_last_price(alert_id, price)
      REDIS_POOL.with { |r| r.setex("alert_state:#{alert_id}:last_price", 3600, price.to_s) }
    end
  end
end
