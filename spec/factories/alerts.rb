# frozen_string_literal: true

FactoryBot.define do
  factory :alert do
    user
    symbol { "AAPL" }
    alert_type { "price_above" }
    condition { { "value" => 150.0 } }
    cooldown_minutes { 15 }
    active { true }

    trait :price_below do
      alert_type { "price_below" }
      condition { { "value" => 100.0 } }
    end

    trait :percent_change do
      alert_type { "price_change_pct" }
      condition { { "value" => 5.0 } }
    end

    trait :rsi_overbought do
      alert_type { "rsi_overbought" }
      condition { { "value" => 70 } }
    end

    trait :rsi_oversold do
      alert_type { "rsi_oversold" }
      condition { { "value" => 30 } }
    end

    trait :volume_spike do
      alert_type { "volume_spike" }
      condition { { "value" => 200 } }
    end

    trait :macd_crossover do
      alert_type { "macd_crossover" }
      condition { {} }
    end

    trait :bollinger_breakout do
      alert_type { "bollinger_breakout" }
      condition { {} }
    end

    trait :news_sentiment do
      alert_type { "news_sentiment" }
      condition { {} }
    end

    trait :triggered do
      last_triggered_at { 1.hour.ago }
      trigger_count { 1 }
    end

    trait :on_cooldown do
      last_triggered_at { 5.minutes.ago }
      trigger_count { 1 }
    end
  end
end
