# frozen_string_literal: true

FactoryBot.define do
  factory :price_snapshot do
    symbol { "AAPL" }
    close_price { 195.50 }
    volume { 50_000_000 }
    sequence(:timestamp) { |n| n.minutes.ago }
    interval { "1m" }
    source { "finnhub" }
  end
end
