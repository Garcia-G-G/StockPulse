# frozen_string_literal: true

module Notifications
  class Manager
    SENDERS = {
      telegram: "Notifications::TelegramSender",
      whatsapp: "Notifications::WhatsappSender",
      email: "Notifications::EmailSender"
    }.freeze

    def notify(user:, message:, channels: nil)
      channels ||= user.enabled_channels
      return if user.muted?

      channels.each do |channel|
        sender_class = SENDERS[channel.to_sym]&.constantize
        next unless sender_class

        sender_class.new.send_message(user: user, message: message)
      rescue StandardError => e
        SystemLog.log(level: "error", component: "notifications", message: "Failed to send #{channel}: #{e.message}")
      end
    end
  end
end
