# frozen_string_literal: true

module Notifications
  class EmailSender
    def send_notification(user:, alert:, price_data:, ai_analysis:, formatter:)
      raise "No email for user #{user.id}" unless user.email.present?

      email_data = formatter.format_email_body(alert, price_data, ai_analysis)
      subject = formatter.format_email_subject(alert)

      mail = AlertMailer.price_alert(
        user: user,
        alert: alert,
        price_data: price_data,
        ai_analysis: ai_analysis,
        email_data: email_data,
        subject: subject
      ).deliver_now

      { message_id: mail&.message_id }
    end

    # For simple text messages (used by legacy notify path)
    def send_message(user:, message:)
      return unless user.email.present?

      AlertMailer.price_alert(
        user: user,
        alert: OpenStruct.new(symbol: "INFO", alert_type: "price_above", condition: {}),
        price_data: { close: 0, change_percent: 0 },
        ai_analysis: nil,
        email_data: { label: "Notificación", trigger_desc: message },
        subject: "[StockPulse] Notificación"
      ).deliver_now
    end
  end
end
