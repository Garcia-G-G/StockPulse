# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                       :bigint           not null, primary key
#  email                    :string
#  is_active                :boolean          default(TRUE), not null
#  muted_until              :datetime
#  notification_preferences :jsonb            not null
#  timezone                 :string           default("US/Eastern"), not null
#  username                 :string(50)       not null
#  whatsapp_number          :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  telegram_chat_id         :string
#
# Indexes
#
#  index_users_on_telegram_chat_id  (telegram_chat_id) UNIQUE
#  index_users_on_username          (username) UNIQUE
#
class User < ApplicationRecord
  include Notifiable

  has_many :watchlist_items, dependent: :destroy
  has_many :alerts, dependent: :destroy
  has_many :alert_histories, dependent: :destroy

  validates :username, presence: true, uniqueness: true, length: { maximum: 50 }
  validates :telegram_chat_id, uniqueness: true, allow_nil: true
  validates :whatsapp_number, format: { with: /\A\+[1-9]\d{1,14}\z/, message: "must be in E.164 format" }, allow_nil: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validates :timezone, presence: true
  validate :at_least_one_notification_channel

  scope :active, -> { where(is_active: true) }

  private

  def at_least_one_notification_channel
    return if telegram_chat_id.present? || email.present? || whatsapp_number.present?

    errors.add(:base, "at least one notification channel (telegram, email, or whatsapp) must be present")
  end
end
