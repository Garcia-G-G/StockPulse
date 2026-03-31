# frozen_string_literal: true

module Notifications
  class TelegramSender
    def send_message(user:, message:)
      raise NotImplementedError, "TelegramSender#send_message not yet implemented"
    end
  end
end
