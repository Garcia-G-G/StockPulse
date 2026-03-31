# frozen_string_literal: true

FactoryBot.define do
  factory :watchlist_item do
    user
    symbol { "AAPL" }
    company_name { "Apple Inc." }
    exchange { "NASDAQ" }
    asset_type { "stock" }
    priority { 3 }
    is_active { true }

    trait :high_priority do
      priority { 5 }
    end

    trait :inactive do
      is_active { false }
    end

    trait :crypto do
      symbol { "BTC" }
      company_name { "Bitcoin" }
      asset_type { "crypto" }
      exchange { "CRYPTO" }
    end
  end
end
