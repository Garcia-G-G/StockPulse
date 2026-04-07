# frozen_string_literal: true

class SendNotificationJob < ApplicationJob
  queue_as :critical
  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  def perform(user_id:, message:, channels: nil)
    user = User.find(user_id)
    Notifications::Manager.new.notify(user: user, message: message, channels: channels)
  end
end
