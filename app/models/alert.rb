# frozen_string_literal: true

class Alert < ApplicationRecord
  include Alertable

  belongs_to :user
  has_many :alert_histories, dependent: :destroy

  validates :symbol, presence: true
  # These must match the evaluators registered in Alerts::Engine::EVALUATORS
  VALID_ALERT_TYPES = %w[
    price_above price_below price_change_pct
    rsi_overbought rsi_oversold macd_crossover bollinger_breakout
    volume_spike news_sentiment multi_condition
  ].freeze

  validates :alert_type, presence: true, inclusion: { in: VALID_ALERT_TYPES }
  validates :cooldown_minutes, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 10_080 }
  validates :condition, presence: true

  scope :active, -> { where(active: true) }

  before_validation :upcase_symbol

  private

  def upcase_symbol
    self.symbol = symbol&.upcase
  end
end
