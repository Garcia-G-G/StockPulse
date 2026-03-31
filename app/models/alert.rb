# frozen_string_literal: true

class Alert < ApplicationRecord
  include Alertable

  belongs_to :user
  has_many :alert_histories, dependent: :destroy

  validates :symbol, presence: true
  validates :alert_type, presence: true, inclusion: {
    in: %w[price_above price_below price_change_pct rsi_overbought rsi_oversold
           macd_crossover bollinger_breakout volume_spike news_sentiment multi_condition]
  }
  validates :cooldown_minutes, numericality: { greater_than_or_equal_to: 1 }

  scope :active, -> { where(active: true) }

  before_validation :upcase_symbol

  private

  def upcase_symbol
    self.symbol = symbol&.upcase
  end
end
