class QuotesController < ApplicationController
  layout "landing"

  CRYPTO_SYMBOLS = {
    "BTC" => "BINANCE:BTCUSDT",
    "ETH" => "BINANCE:ETHUSDT",
    "SOL" => "BINANCE:SOLUSDT",
    "DOGE" => "BINANCE:DOGEUSDT",
    "XRP" => "BINANCE:XRPUSDT",
    "ADA" => "BINANCE:ADAUSDT",
    "DOT" => "BINANCE:DOTUSDT",
    "AVAX" => "BINANCE:AVAXUSDT",
    "MATIC" => "BINANCE:MATICUSDT",
    "LINK" => "BINANCE:LINKUSDT",
  }.freeze

  CRYPTO_NAMES = {
    "BTC" => "Bitcoin", "ETH" => "Ethereum", "SOL" => "Solana",
    "DOGE" => "Dogecoin", "XRP" => "Ripple", "ADA" => "Cardano",
    "DOT" => "Polkadot", "AVAX" => "Avalanche", "MATIC" => "Polygon",
    "LINK" => "Chainlink",
  }.freeze

  def show
    @symbol = params[:symbol].to_s.strip.upcase
    api_key = ENV["FINNHUB_API_KEY"]

    # Determine the Finnhub symbol (crypto uses BINANCE: prefix)
    finnhub_symbol = CRYPTO_SYMBOLS[@symbol] || @symbol
    @is_crypto = CRYPTO_SYMBOLS.key?(@symbol)

    @quote = Rails.cache.fetch("finnhub_quote_#{finnhub_symbol}", expires_in: 2.minutes) do
      resp = Faraday.get("https://finnhub.io/api/v1/quote?symbol=#{finnhub_symbol}&token=#{api_key}")
      JSON.parse(resp.body)
    rescue
      nil
    end

    if @is_crypto
      @profile = { "name" => CRYPTO_NAMES[@symbol] || @symbol, "exchange" => "Crypto", "finnhubIndustry" => "Cryptocurrency" }
    else
      @profile = Rails.cache.fetch("finnhub_profile_#{@symbol}", expires_in: 1.hour) do
        resp = Faraday.get("https://finnhub.io/api/v1/stock/profile2?symbol=#{@symbol}&token=#{api_key}")
        JSON.parse(resp.body)
      rescue
        nil
      end
    end

    redirect_to root_path, alert: "Symbol not found" if @quote.nil? || @quote["c"].to_f.zero?
  end
end
