# frozen_string_literal: true

module Notifiable
  extend ActiveSupport::Concern

  included do
    scope :notifications_enabled, -> { where(notifications_muted: false) }
  end

  def notification_channels
    channels = []
    channels << :telegram if telegram_chat_id.present?
    channels << :email if email.present?
    channels << :whatsapp if whatsapp_number.present?
    channels
  end

  def can_receive_notifications?
    active? && !notifications_muted?
  end
end
