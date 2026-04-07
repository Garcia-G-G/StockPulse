# frozen_string_literal: true

class User < ApplicationRecord
  include Notifiable

  has_many :watchlist_items, dependent: :destroy
  has_many :alerts, dependent: :destroy
  has_many :alert_histories, dependent: :destroy

  validates :telegram_chat_id, uniqueness: true, allow_blank: true
  validates :email, uniqueness: true, allow_blank: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" },
                    if: -> { email.present? }
  validates :whatsapp_number, format: { with: /\A\+?[1-9]\d{6,14}\z/, message: "must be a valid phone number" },
                              allow_blank: true

  scope :active, -> { where(active: true) }
end
