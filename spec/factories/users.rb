# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:telegram_chat_id) { |n| "chat_#{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    name { "Test User" }
    active { true }
    notifications_muted { false }
    settings { {} }

    trait :muted do
      notifications_muted { true }
    end

    trait :inactive do
      active { false }
    end

    trait :with_whatsapp do
      whatsapp_number { "+1234567890" }
    end
  end
end
