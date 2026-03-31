# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:username) { |n| "user_#{n}" }
    sequence(:telegram_chat_id) { |n| "#{100_000 + n}" }
    email { Faker::Internet.email }
    timezone { "US/Eastern" }
    is_active { true }

    trait :with_whatsapp do
      whatsapp_number { "+1#{Faker::Number.number(digits: 10)}" }
    end

    trait :muted do
      muted_until { 1.hour.from_now }
    end

    trait :no_telegram do
      telegram_chat_id { nil }
    end
  end
end
