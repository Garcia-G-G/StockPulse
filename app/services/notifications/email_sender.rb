# frozen_string_literal: true

module Notifications
  class EmailSender
    def send_message(user:, message:)
      return unless user.email.present?

      if message.is_a?(Hash) && message[:alert] && message[:data]
        AlertMailer.price_alert(
          user: user,
          alert: message[:alert],
          data: message[:data]
        ).deliver_later
      else
        text = Notifications::Formatter.new.format(message, channel: :email)
        AlertMailer.price_alert(
          user: user,
          alert: Struct.new(:symbol, :alert_type, keyword_init: true).new(symbol: "SYSTEM", alert_type: "notification"),
          data: { message: text }
        ).deliver_later
      end
    end
  end
end
