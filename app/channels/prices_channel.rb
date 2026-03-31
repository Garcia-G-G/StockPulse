# frozen_string_literal: true

class PricesChannel < ApplicationCable::Channel
  def subscribed
    symbol = params[:symbol]

    if symbol.present?
      stream_from "prices:#{symbol}"
    else
      stream_from "prices:all"
    end
  end

  def unsubscribed
    stop_all_streams
  end

  def self.broadcast_price(symbol, data)
    ActionCable.server.broadcast("prices:#{symbol}", data)
    ActionCable.server.broadcast("prices:all", data)
  end
end
