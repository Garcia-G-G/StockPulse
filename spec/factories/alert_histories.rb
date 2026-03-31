# frozen_string_literal: true

FactoryBot.define do
  factory :alert_history do
    alert
    user
    symbol { "AAPL" }
    alert_type { "price_above" }
    triggered_at { Time.current }
    price_at_trigger { 195.50 }
    condition_snapshot { { target_price: 200.0 } }
    notification_results { {} }
  end
end
