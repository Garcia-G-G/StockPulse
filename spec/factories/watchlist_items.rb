# frozen_string_literal: true

FactoryBot.define do
  factory :watchlist_item do
    user
    symbol { "AAPL" }
    name { "Apple Inc." }
    exchange { "NASDAQ" }
    active { true }
    added_at { Time.current }
  end
end
