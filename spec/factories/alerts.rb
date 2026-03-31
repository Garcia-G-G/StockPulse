# frozen_string_literal: true

FactoryBot.define do
  factory :alert do
    user
    symbol { "AAPL" }
    alert_type { "price_above" }
    condition { { target_price: 200.0 } }
    is_enabled { true }
    cooldown_minutes { 15 }
    trigger_count { 0 }
    notification_channels { %w[telegram] }

    trait :price_below do
      alert_type { "price_below" }
      condition { { target_price: 150.0 } }
    end

    trait :percent_change_up do
      alert_type { "percent_change_up" }
      condition { { threshold_percent: 5.0, timeframe: "1d" } }
    end

    trait :percent_change_down do
      alert_type { "percent_change_down" }
      condition { { threshold_percent: 5.0, timeframe: "1d" } }
    end

    trait :price_range_break do
      alert_type { "price_range_break" }
      condition { { lower: 180.0, upper: 200.0 } }
    end

    trait :rsi_overbought do
      alert_type { "rsi_overbought" }
      condition { { threshold: 70 } }
    end

    trait :rsi_oversold do
      alert_type { "rsi_oversold" }
      condition { { threshold: 30 } }
    end

    trait :volume_spike do
      alert_type { "volume_spike" }
      condition { { threshold_percent: 200 } }
    end

    trait :volume_dry do
      alert_type { "volume_dry" }
      condition { { threshold_percent: 50 } }
    end

    trait :news_impact do
      alert_type { "news_high_impact" }
      condition { { min_sentiment_score: 0.7 } }
    end

    trait :macd_bullish do
      alert_type { "macd_crossover_bullish" }
      condition { {} }
    end

    trait :macd_bearish do
      alert_type { "macd_crossover_bearish" }
      condition { {} }
    end

    trait :triggered do
      last_triggered_at { 1.hour.ago }
      trigger_count { 1 }
    end

    trait :in_cooldown do
      last_triggered_at { 5.minutes.ago }
      cooldown_minutes { 15 }
    end

    trait :one_time do
      is_one_time { true }
    end
  end
end
