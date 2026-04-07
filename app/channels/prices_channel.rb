# frozen_string_literal: true

class PricesChannel < ApplicationCable::Channel
  def subscribed
    if params[:symbol].present?
      stream_from "prices:#{params[:symbol].upcase}"
    else
      stream_from "prices"
    end
  end

  def unsubscribed
    stop_all_streams
  end

  def self.broadcast_price(symbol, data)
    ActionCable.server.broadcast("prices", { symbol: symbol, **data })
    ActionCable.server.broadcast("prices:#{symbol}", { symbol: symbol, **data })
  end
end
