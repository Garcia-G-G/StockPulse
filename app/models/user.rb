# frozen_string_literal: true

class User < ApplicationRecord
  include Notifiable

  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable

  has_many :watchlist_items, dependent: :destroy
  has_many :alerts, dependent: :destroy
  has_many :alert_histories, dependent: :destroy

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :telegram_chat_id, uniqueness: true, allow_blank: true
  validates :whatsapp_number, format: { with: /\A\+?[1-9]\d{6,14}\z/, message: "must be a valid phone number" },
                              allow_blank: true

  scope :active, -> { where(active: true) }
end
