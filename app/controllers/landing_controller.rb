# frozen_string_literal: true

class LandingController < ApplicationController
  layout "landing"

  CRYPTO_MAP = {
    "BTC" => { symbol: "BINANCE:BTCUSDT", name: "Bitcoin", display: "BTC", type: "Crypto" },
    "BITCOIN" => { symbol: "BINANCE:BTCUSDT", name: "Bitcoin", display: "BTC", type: "Crypto" },
    "ETH" => { symbol: "BINANCE:ETHUSDT", name: "Ethereum", display: "ETH", type: "Crypto" },
    "ETHEREUM" => { symbol: "BINANCE:ETHUSDT", name: "Ethereum", display: "ETH", type: "Crypto" },
    "SOL" => { symbol: "BINANCE:SOLUSDT", name: "Solana", display: "SOL", type: "Crypto" },
    "SOLANA" => { symbol: "BINANCE:SOLUSDT", name: "Solana", display: "SOL", type: "Crypto" },
    "DOGE" => { symbol: "BINANCE:DOGEUSDT", name: "Dogecoin", display: "DOGE", type: "Crypto" },
    "XRP" => { symbol: "BINANCE:XRPUSDT", name: "Ripple", display: "XRP", type: "Crypto" },
    "ADA" => { symbol: "BINANCE:ADAUSDT", name: "Cardano", display: "ADA", type: "Crypto" },
    "DOT" => { symbol: "BINANCE:DOTUSDT", name: "Polkadot", display: "DOT", type: "Crypto" },
    "AVAX" => { symbol: "BINANCE:AVAXUSDT", name: "Avalanche", display: "AVAX", type: "Crypto" },
    "MATIC" => { symbol: "BINANCE:MATICUSDT", name: "Polygon", display: "MATIC", type: "Crypto" },
    "LINK" => { symbol: "BINANCE:LINKUSDT", name: "Chainlink", display: "LINK", type: "Crypto" },
  }.freeze

  def index
    redirect_to authenticated_root_path if user_signed_in?
  end

  LANDING_STOCK_SYMBOLS = %w[AAPL MSFT GOOGL NVDA TSLA AMZN META AMD NFLX CRM SPOT].freeze
  LANDING_CRYPTO_SYMBOLS = %w[BINANCE:BTCUSDT BINANCE:ETHUSDT BINANCE:SOLUSDT].freeze

  def prices
    payload = Rails.cache.fetch("landing:prices", expires_in: 30.seconds) do
      quotes = ParallelQuoteFetcher.new.fetch(LANDING_STOCK_SYMBOLS + LANDING_CRYPTO_SYMBOLS)
      quotes.map do |symbol, data|
        display = symbol.sub(/\ABINANCE:/, "").sub(/USDT\z/, "")
        { s: display, p: data[:price].round(2), c: data[:change_percent].round(2) }
      end
    end

    render json: payload
  end

  def search
    query = params[:q].to_s.strip.upcase
    return render json: [] if query.length < 1

    api_key = ENV["FINNHUB_API_KEY"]
    return render json: [] unless api_key.present?

    results = []

    # Check crypto first
    crypto = CRYPTO_MAP[query]
    if crypto
      quote = fetch_quote(crypto[:symbol], api_key)
      results << {
        symbol: crypto[:display],
        name: crypto[:name],
        type: crypto[:type],
        price: quote&.dig("c")&.to_f&.round(2),
        change: quote&.dig("dp")&.to_f&.round(2),
        finnhub_symbol: crypto[:symbol]
      }
    end

    # Also search Finnhub for stocks
    stock_results = Rails.cache.fetch("finnhub_search_#{query}", expires_in: 10.minutes) do
      response = Faraday.get("https://finnhub.io/api/v1/search?q=#{CGI.escape(query)}&token=#{api_key}")
      data = JSON.parse(response.body)
      (data["result"] || []).first(6).map do |r|
        { symbol: r["symbol"], name: r["description"], type: r["type"] }
      end
    rescue
      []
    end

    # Enrich top stock results with prices
    stock_results.first(4).each do |r|
      quote = fetch_quote(r[:symbol], api_key)
      if quote && quote["c"].to_f > 0
        r[:price] = quote["c"].to_f.round(2)
        r[:change] = quote["dp"].to_f.round(2)
      end
    end

    results.concat(stock_results)
    render json: results
  rescue => e
    Rails.logger.error("Search failed: #{e.message}")
    render json: []
  end

  private

  def fetch_quote(symbol, api_key)
    Rails.cache.fetch("finnhub_quote_#{symbol}", expires_in: 5.minutes) do
      resp = Faraday.get("https://finnhub.io/api/v1/quote?symbol=#{symbol}&token=#{api_key}")
      JSON.parse(resp.body)
    rescue
      nil
    end
  end
end
