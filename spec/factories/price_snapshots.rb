# frozen_string_literal: true

FactoryBot.define do
  factory :price_snapshot do
    symbol { "AAPL" }
    price { 150.0 }
    open { 148.0 }
    high { 152.0 }
    low { 147.0 }
    volume { 50_000_000 }
    change_percent { 1.5 }
    captured_at { Time.current }
  end
end
