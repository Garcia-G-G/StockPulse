# frozen_string_literal: true

FactoryBot.define do
  factory :system_log do
    level { "info" }
    component { "test" }
    message { Faker::Lorem.sentence }
  end
end
