# frozen_string_literal: true

class AlertHistorySerializer
  include JSONAPI::Serializer

  attributes :symbol, :alert_type, :message, :data, :channels_notified, :triggered_at
  belongs_to :alert
  belongs_to :user
end
