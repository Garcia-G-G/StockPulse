# frozen_string_literal: true

class SendNotificationJob < ApplicationJob
  queue_as :critical

  def perform(user_id:, message:, channels: nil)
    raise NotImplementedError, "SendNotificationJob#perform not yet implemented"
  end
end
