# frozen_string_literal: true

class EvaluateAlertsJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: 0

  def perform(symbol:, price_data:)
    engine = Alerts::Engine.new
    results = engine.evaluate_all(symbol: symbol, price_data: price_data)

    results.each do |result|
      alert = result[:alert]
      AlertHistory.create!(
        alert: alert,
        user: alert.user,
        symbol: alert.symbol,
        alert_type: alert.alert_type,
        message: result[:message],
        data: result[:data],
        channels_notified: alert.user.notification_channels,
        triggered_at: Time.current
      )

      SendNotificationJob.perform_later(user_id: alert.user_id, message: result[:message])
    end
  rescue StandardError => e
    SystemLog.log(
      level: "error",
      component: "evaluate_alerts",
      message: "Failed for #{symbol}: #{e.message}",
      data: { backtrace: e.backtrace&.first(5) }
    )
  end
end
