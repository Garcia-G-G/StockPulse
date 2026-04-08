# frozen_string_literal: true

class LandingController < ApplicationController
  layout "landing"

  def index
    redirect_to authenticated_root_path if user_signed_in?
  end

  def prices
    symbols = %w[AAPL MSFT GOOGL NVDA TSLA AMZN META AMD NFLX CRM SPOT]
    api_key = ENV["FINNHUB_API_KEY"]

    prices = symbols.filter_map do |sym|
      response = Faraday.get("https://finnhub.io/api/v1/quote?symbol=#{sym}&token=#{api_key}")
      data = JSON.parse(response.body)
      { s: sym, p: data["c"].to_f.round(2), c: data["dp"].to_f.round(2) }
    rescue StandardError
      nil
    end

    # Add crypto with Finnhub crypto symbols
    %w[BINANCE:BTCUSDT BINANCE:ETHUSDT BINANCE:SOLUSDT].each do |sym|
      response = Faraday.get("https://finnhub.io/api/v1/quote?symbol=#{sym}&token=#{api_key}")
      data = JSON.parse(response.body)
      display = sym.split(":").last.gsub("USDT", "")
      prices << { s: display, p: data["c"].to_f.round(2), c: data["dp"].to_f.round(2) }
    rescue StandardError
      nil
    end

    render json: prices
  end
end
