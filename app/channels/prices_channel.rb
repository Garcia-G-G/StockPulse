# frozen_string_literal: true

class PricesChannel < ApplicationCable::Channel
  def subscribed
    symbol = params[:symbol]
    if symbol.present?
      # Validate symbol format to prevent channel name injection
      symbol = symbol.upcase.gsub(/[^A-Z0-9.]/, "")
      reject and return if symbol.blank? || symbol.length > 10

      stream_from "prices:#{symbol}"
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
