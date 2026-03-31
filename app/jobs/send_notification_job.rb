# frozen_string_literal: true

class SendNotificationJob < ApplicationJob
  queue_as :critical

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(user_id:, alert_id:, aggregated_price:, ai_analysis: nil)
    user = User.find(user_id)
    alert = Alert.find(alert_id)

    unless alert.is_enabled
      Rails.logger.info("[SendNotificationJob] Alert #{alert_id} disabled, skipping")
      return
    end

    results = Notifications::Manager.new.dispatch(
      user: user,
      alert: alert,
      aggregated_price: aggregated_price.deep_symbolize_keys,
      ai_analysis: ai_analysis&.deep_symbolize_keys
    )

    Rails.logger.info(
      "[SendNotificationJob] Dispatched alert #{alert_id} to #{results.size} channels: " \
      "#{results.map { |r| "#{r[:channel]}=#{r[:success]}" }.join(', ')}"
    )
  rescue StandardError => e
    SystemLog.log(
      level: "error",
      component: "notifications",
      message: "SendNotificationJob failed for alert #{alert_id}: #{e.message}",
      details: { alert_id: alert_id, user_id: user_id, error: e.class.name }
    )
    raise
  end
end
