# frozen_string_literal: true

class WatchlistItemSerializer
  include JSONAPI::Serializer

  attributes :symbol, :name, :exchange, :active, :added_at, :created_at
  belongs_to :user
end
