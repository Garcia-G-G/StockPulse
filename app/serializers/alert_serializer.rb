# frozen_string_literal: true

class AlertSerializer
  include JSONAPI::Serializer

  attributes :symbol, :alert_type, :condition, :channels, :cooldown_minutes,
             :last_triggered_at, :trigger_count, :active, :created_at
  belongs_to :user
end
