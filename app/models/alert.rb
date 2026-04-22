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

  # Per-alert notification channels: array of strings like ["email", "telegram"].
  # Backed by the `channels` jsonb column. Coerces the legacy hash shape
  # ({"email" => true}) to the array shape on read.
  def notification_channels
    case channels
    when Array
      channels.map(&:to_s)
    when Hash
      channels.select { |_, v| v }.keys.map(&:to_s)
    else
      []
    end
  end

  def notification_channels=(list)
    allowed = Notifications::Manager::SENDERS.keys.map(&:to_s)
    self.channels = Array(list).map(&:to_s).uniq.select { |c| allowed.include?(c) }
  end

  # Per-alert selection when set, otherwise the user's globally configured channels.
  def resolved_notification_channels
    own = notification_channels
    own.any? ? own : user.notification_channels.map(&:to_s)
  end

  def human_description
    cond = condition || {}
    value = cond["value"] || cond[:value]
    case alert_type
    when "price_above"      then "Alert when #{symbol} goes above $#{format_value(value)}"
    when "price_below"      then "Alert when #{symbol} drops below $#{format_value(value)}"
    when "price_change_pct"
      dir = cond["direction"] || cond[:direction] || "any"
      arrow = dir == "up" ? "+" : dir == "down" ? "-" : "±"
      "Alert when #{symbol} moves #{arrow}#{format_value(value)}%"
    when "volume_spike"     then "Alert when #{symbol} volume exceeds #{format_value(value)}x average"
    when "rsi_overbought"   then "Alert when #{symbol} RSI > #{value || 70}"
    when "rsi_oversold"     then "Alert when #{symbol} RSI < #{value || 30}"
    else                         "#{alert_type.tr('_', ' ')} alert for #{symbol}"
    end
  end

  private

  def format_value(value)
    return "?" if value.nil?
    float = value.to_f
    float == float.to_i ? float.to_i.to_s : format("%.2f", float)
  end

  def upcase_symbol
    self.symbol = symbol&.upcase
  end
end
