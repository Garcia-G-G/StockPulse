# frozen_string_literal: true

class UserSerializer
  include JSONAPI::Serializer

  attributes :name, :email, :telegram_chat_id, :active, :notifications_muted, :created_at
end
