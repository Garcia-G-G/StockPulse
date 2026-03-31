# frozen_string_literal: true

module Notifications
  class Manager
    MAX_RETRIES = 3
    BACKOFF_BASE = 1 # seconds

    SENDERS = {
      telegram: Notifications::TelegramSender,
      whatsapp: Notifications::WhatsappSender,
      email: Notifications::EmailSender
    }.freeze

    def dispatch(user:, alert:, aggregated_price:, ai_analysis: nil)
      channels = user.enabled_channels
      return [] if channels.empty?

      formatter = Notifications::Formatter.new
      results = []

      threads = channels.map do |channel|
        Thread.new do
          result = send_to_channel(
            channel: channel,
            user: user,
            alert: alert,
            aggregated_price: aggregated_price,
            ai_analysis: ai_analysis,
            formatter: formatter
          )
          results << result
        end
      end

      threads.each { |t| t.join(30) }

      if results.all? { |r| !r[:success] }
        SystemLog.log(
          level: "critical",
          component: "notifications",
          message: "All notification channels failed for alert #{alert.id} (#{alert.symbol})",
          details: { alert_id: alert.id, user_id: user.id, results: results }
        )
      end

      update_alert_history(alert, results)
      results
    end

    private

    def send_to_channel(channel:, user:, alert:, aggregated_price:, ai_analysis:, formatter:)
      sender = SENDERS[channel]
      return { channel: channel, success: false, error: "Unknown channel" } unless sender

      attempt = 0
      last_error = nil

      while attempt < MAX_RETRIES
        attempt += 1
        begin
          result = sender.new.send_notification(
            user: user,
            alert: alert,
            price_data: aggregated_price,
            ai_analysis: ai_analysis,
            formatter: formatter
          )
          return { channel: channel, success: true, **result }
        rescue StandardError => e
          last_error = e
          Rails.logger.warn(
            "[NotificationManager] #{channel} attempt #{attempt}/#{MAX_RETRIES} failed: #{e.message}"
          )
          sleep(BACKOFF_BASE * (2**(attempt - 1))) if attempt < MAX_RETRIES
        end
      end

      Rails.logger.error("[NotificationManager] #{channel} failed after #{MAX_RETRIES} retries: #{last_error&.message}")
      { channel: channel, success: false, error: last_error&.message }
    end

    def update_alert_history(alert, results)
      history = AlertHistory.where(alert: alert).order(triggered_at: :desc).first
      return unless history

      notification_results = results.each_with_object({}) do |r, hash|
        hash[r[:channel]] = { success: r[:success], message_id: r[:message_id], error: r[:error] }
      end

      history.update(notification_results: notification_results)
    rescue StandardError => e
      Rails.logger.error("[NotificationManager] Failed to update AlertHistory: #{e.message}")
    end
  end
end
