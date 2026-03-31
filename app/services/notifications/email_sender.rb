# frozen_string_literal: true

module Notifications
  class EmailSender
    def send_message(user:, message:)
      raise NotImplementedError, "EmailSender#send_message not yet implemented"
    end
  end
end
