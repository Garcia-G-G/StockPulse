# frozen_string_literal: true

class AlphaVantageClient < BaseClient
  def initialize
    super(
      base_url: "https://www.alphavantage.co",
      rate_limit_key: "alpha_vantage",
      rate_limit_max: ENV.fetch("ALPHA_VANTAGE_RATE_LIMIT_PER_DAY", 25).to_i,
      rate_limit_period: 86_400
    )
  end

  def rsi(symbol, interval: "daily", time_period: 14)
    technical_indicator("RSI", symbol, interval: interval, time_period: time_period)
  end

  def macd(symbol, interval: "daily")
    technical_indicator("MACD", symbol, interval: interval)
  end

  def bollinger_bands(symbol, interval: "daily", time_period: 20)
    technical_indicator("BBANDS", symbol, interval: interval, time_period: time_period)
  end

  def sma(symbol, interval: "daily", time_period: 50)
    technical_indicator("SMA", symbol, interval: interval, time_period: time_period)
  end

  def ema(symbol, interval: "daily", time_period: 20)
    technical_indicator("EMA", symbol, interval: interval, time_period: time_period)
  end

  private

  def technical_indicator(function, symbol, interval: "daily", time_period: nil)
    params = {
      function: function,
      symbol: symbol,
      interval: interval,
      series_type: "close",
      apikey: api_key
    }
    params[:time_period] = time_period if time_period
    get("/query", params)
  end

  def api_key
    ENV.fetch("ALPHA_VANTAGE_API_KEY", "")
  end
end
