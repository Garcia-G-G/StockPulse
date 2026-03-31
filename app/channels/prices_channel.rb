# frozen_string_literal: true

class PricesChannel < ApplicationCable::Channel
  def subscribed
    stream_from "prices"
  end

  def unsubscribed
    # Cleanup when channel is unsubscribed
  end

  def self.broadcast_price(symbol, data)
    ActionCable.server.broadcast("prices", { symbol: symbol, **data })
  end
end
