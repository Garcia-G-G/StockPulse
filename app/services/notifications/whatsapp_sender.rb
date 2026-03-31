# frozen_string_literal: true

module Notifications
  class WhatsappSender
    def send_message(user:, message:)
      raise NotImplementedError, "WhatsappSender#send_message not yet implemented"
    end
  end
end
