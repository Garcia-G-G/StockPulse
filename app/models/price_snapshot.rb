# frozen_string_literal: true

# == Schema Information
#
# Table name: price_snapshots
#
#  id             :bigint           not null, primary key
#  change_percent :decimal(8, 4)
#  close_price    :decimal(12, 4)   not null
#  high_price     :decimal(12, 4)
#  interval       :string           default("1m"), not null
#  low_price      :decimal(12, 4)
#  open_price     :decimal(12, 4)
#  source         :string           default("finnhub"), not null
#  symbol         :string(10)       not null
#  timestamp      :datetime         not null
#  volume         :bigint           default(0), not null
#  vwap           :decimal(12, 4)
#
# Indexes
#
#  index_price_snapshots_on_symbol_and_interval_and_timestamp  (symbol,interval,timestamp)
#  index_price_snapshots_on_symbol_and_timestamp               (symbol,timestamp)
#  index_price_snapshots_on_symbol_and_timestamp_and_interval  (symbol,timestamp,interval) UNIQUE
#
class PriceSnapshot < ApplicationRecord
  VALID_INTERVALS = %w[1m 5m 15m 1h 1d].freeze

  DEFAULT_RETENTION = {
    "1m" => 7,
    "5m" => 7,
    "15m" => 30,
    "1h" => 90,
    "1d" => 365
  }.freeze

  validates :symbol, presence: true, length: { maximum: 10 }
  validates :close_price, presence: true, numericality: { greater_than: 0 }
  validates :volume, numericality: { greater_than_or_equal_to: 0 }
  validates :timestamp, presence: true
  validates :interval, presence: true, inclusion: { in: VALID_INTERVALS }

  scope :for_symbol, ->(sym) { where(symbol: sym.upcase) }
  scope :since, ->(time) { where(timestamp: time..) }
  scope :by_interval, ->(interval) { where(interval: interval) }
  scope :latest_first, -> { order(timestamp: :desc) }

  before_validation :upcase_symbol

  def self.latest_price(symbol)
    for_symbol(symbol).latest_first.first
  end

  def self.cleanup_old!(retention = DEFAULT_RETENTION)
    retention.each do |interval, days|
      by_interval(interval)
        .where(timestamp: ...days.days.ago)
        .delete_all
    end
  end

  private

  def upcase_symbol
    self.symbol = symbol&.upcase&.strip
  end
end
