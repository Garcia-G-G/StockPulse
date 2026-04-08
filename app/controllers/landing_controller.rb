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

  def search
    query = params[:q].to_s.strip.upcase
    return render json: [] if query.length < 1

    api_key = ENV["FINNHUB_API_KEY"]
    return render json: [] unless api_key.present?

    # Cache for 10 minutes to avoid hitting rate limits
    results = Rails.cache.fetch("finnhub_search_#{query}", expires_in: 10.minutes) do
      response = Faraday.get("https://finnhub.io/api/v1/search?q=#{CGI.escape(query)}&token=#{api_key}")
      data = JSON.parse(response.body)
      (data["result"] || []).first(8).map do |r|
        { symbol: r["symbol"], name: r["description"], type: r["type"] }
      end
    end

    # Fetch current price for top 5 results
    results.first(5).each do |r|
      quote = Rails.cache.fetch("finnhub_quote_#{r[:symbol]}", expires_in: 5.minutes) do
        resp = Faraday.get("https://finnhub.io/api/v1/quote?symbol=#{r[:symbol]}&token=#{api_key}")
        JSON.parse(resp.body)
      rescue
        nil
      end
      if quote && quote["c"].to_f > 0
        r[:price] = quote["c"].to_f.round(2)
        r[:change] = quote["dp"].to_f.round(2)
      end
    end

    render json: results
  rescue => e
    Rails.logger.error("Search failed: #{e.message}")
    render json: []
  end
end
