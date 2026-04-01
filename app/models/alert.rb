# frozen_string_literal: true

# == Schema Information
#
# Table name: alerts
#
#  id                    :bigint           not null, primary key
#  ai_analysis_enabled   :boolean          default(TRUE), not null
#  alert_type            :enum             not null
#  condition             :jsonb            not null
#  cooldown_minutes      :integer          default(15), not null
#  is_enabled            :boolean          default(TRUE), not null
#  is_one_time           :boolean          default(FALSE), not null
#  last_triggered_at     :datetime
#  max_triggers          :integer
#  notes                 :text
#  notification_channels :string           default(["telegram"]), is an Array
#  symbol                :string(10)       not null
#  trigger_count         :integer          default(0), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  user_id               :bigint           not null
#
# Indexes
#
#  index_alerts_on_alert_type              (alert_type)
#  index_alerts_on_symbol_and_is_enabled   (symbol,is_enabled)
#  index_alerts_on_user_id                 (user_id)
#  index_alerts_on_user_id_and_is_enabled  (user_id,is_enabled)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class Alert < ApplicationRecord
  include Alertable

  PRICE_TYPES = %w[price_above price_below percent_change_up percent_change_down price_range_break].freeze
  TECHNICAL_TYPES = %w[rsi_overbought rsi_oversold macd_crossover_bullish macd_crossover_bearish
                       bollinger_break_upper bollinger_break_lower sma_golden_cross sma_death_cross].freeze
  VOLUME_TYPES = %w[volume_spike volume_dry].freeze
  NEWS_TYPES = %w[news_high_impact].freeze
  ALL_TYPES = (PRICE_TYPES + TECHNICAL_TYPES + VOLUME_TYPES + NEWS_TYPES).freeze

  VALID_TIMEFRAMES = %w[5m 15m 1h 4h 1d].freeze

  belongs_to :user
  has_many :alert_histories, dependent: :destroy

  validates :symbol, presence: true, length: { maximum: 10 }
  validates :alert_type, presence: true, inclusion: { in: ALL_TYPES }
  validates :cooldown_minutes, numericality: { only_integer: true, in: 1..1440 }
  validates :trigger_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :max_triggers, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :validate_condition_for_type

  scope :price_alerts, -> { where(alert_type: PRICE_TYPES) }
  scope :technical_alerts, -> { where(alert_type: TECHNICAL_TYPES) }
  scope :volume_alerts, -> { where(alert_type: VOLUME_TYPES) }
  scope :news_alerts, -> { where(alert_type: NEWS_TYPES) }

  before_validation :upcase_symbol

  private

  def upcase_symbol
    self.symbol = symbol&.upcase&.strip
  end

  def validate_condition_for_type
    return if alert_type.blank? || condition.blank?

    c = condition.deep_symbolize_keys

    case alert_type
    when "price_above", "price_below"
      validate_target_price(c)
    when "percent_change_up", "percent_change_down"
      validate_percent_with_timeframe(c)
    when "price_range_break"
      validate_price_range(c)
    when "volume_spike", "volume_dry"
      validate_threshold_percent(c)
    when "rsi_overbought", "rsi_oversold"
      validate_rsi_threshold(c)
    when "news_high_impact"
      validate_sentiment_score(c)
    end
  end

  def validate_target_price(c)
    tp = c[:target_price]
    errors.add(:condition, "must include target_price > 0") unless tp.is_a?(Numeric) && tp > 0
  end

  def validate_percent_with_timeframe(c)
    tp = c[:threshold_percent]
    errors.add(:condition, "must include threshold_percent > 0") unless tp.is_a?(Numeric) && tp > 0

    tf = c[:timeframe]
    errors.add(:condition, "must include valid timeframe (#{VALID_TIMEFRAMES.join(', ')})") unless VALID_TIMEFRAMES.include?(tf.to_s)
  end

  def validate_price_range(c)
    lower = c[:lower]
    upper = c[:upper]
    errors.add(:condition, "must include lower and upper prices") unless lower.is_a?(Numeric) && upper.is_a?(Numeric)
    errors.add(:condition, "lower must be less than upper") if lower.is_a?(Numeric) && upper.is_a?(Numeric) && lower >= upper
  end

  def validate_threshold_percent(c)
    tp = c[:threshold_percent]
    errors.add(:condition, "must include threshold_percent > 0") unless tp.is_a?(Numeric) && tp > 0
  end

  def validate_rsi_threshold(c)
    t = c[:threshold]
    errors.add(:condition, "must include threshold between 0 and 100") unless t.is_a?(Numeric) && t >= 0 && t <= 100
  end

  def validate_sentiment_score(c)
    s = c[:min_sentiment_score]
    errors.add(:condition, "must include min_sentiment_score between 0 and 1") unless s.is_a?(Numeric) && s >= 0 && s <= 1
  end
end
