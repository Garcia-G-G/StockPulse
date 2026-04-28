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
    payload = Rails.cache.fetch("landing:prices", expires_in: 60.seconds) do
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

    # Cache the whole enriched response for 60s per query — keystroke-level
    # dedup + instant repeat searches.
    payload = Rails.cache.fetch("search:#{query}", expires_in: 60.seconds) do
      build_search_results(query, api_key)
    end

    render json: payload
  rescue => e
    Rails.logger.error("Search failed: #{e.message}")
    render json: []
  end

  private

  def build_search_results(query, api_key)
    results = []

    # 1) Known crypto mapping.
    crypto = CRYPTO_MAP[query]

    # 2) Finnhub symbol search (only the list of matches — quotes fetched in parallel below).
    stock_results = Rails.cache.fetch("finnhub_search_#{query}", expires_in: 10.minutes) do
      response = Faraday.get("https://finnhub.io/api/v1/search?q=#{CGI.escape(query)}&token=#{api_key}")
      data = JSON.parse(response.body)
      (data["result"] || []).first(6).map do |r|
        { symbol: r["symbol"], name: r["description"], type: r["type"] }
      end
    rescue
      []
    end

    # 3) Build list of every Finnhub symbol we need a quote for (crypto + top 4 stocks) and parallel-fetch in one batch.
    quote_symbols = []
    quote_symbols << crypto[:symbol] if crypto
    stock_results.first(4).each { |r| quote_symbols << r[:symbol] }
    quotes = quote_symbols.any? ? ParallelQuoteFetcher.new.fetch(quote_symbols) : {}

    if crypto
      q = quotes[crypto[:symbol]]
      results << {
        symbol: crypto[:display],
        name: crypto[:name],
        type: crypto[:type],
        price: q && q[:price]&.round(2),
        change: q && q[:change_percent]&.round(2),
        finnhub_symbol: crypto[:symbol]
      }
    end

    stock_results.first(4).each do |r|
      q = quotes[r[:symbol]]
      if q && q[:price] > 0
        r[:price] = q[:price].round(2)
        r[:change] = q[:change_percent].round(2)
      end
    end

    results.concat(stock_results)
    results
  end
end
