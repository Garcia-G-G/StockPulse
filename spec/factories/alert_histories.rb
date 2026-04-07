# frozen_string_literal: true

FactoryBot.define do
  factory :alert_history do
    alert
    user { alert.user }
    symbol { "AAPL" }
    alert_type { "price_above" }
    message { "AAPL reached $155.00 (above $150.00)" }
    triggered_at { Time.current }
    data { { price: 155.0, target: 150.0 } }
    channels_notified { %w[telegram email] }
  end
end
