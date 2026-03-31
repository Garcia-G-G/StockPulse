# frozen_string_literal: true

class AlertHistory < ApplicationRecord
  belongs_to :alert
  belongs_to :user

  validates :symbol, presence: true
  validates :alert_type, presence: true
  validates :message, presence: true
  validates :triggered_at, presence: true

  scope :recent, -> { order(triggered_at: :desc) }
  scope :for_symbol, ->(symbol) { where(symbol: symbol.upcase) }
  scope :today, -> { where(triggered_at: Time.current.beginning_of_day..Time.current.end_of_day) }
end
