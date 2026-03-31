module FinnhubConfig
  API_KEY = ENV.fetch("FINNHUB_API_KEY", "")
  WS_URL = ENV.fetch("FINNHUB_WS_URL", "wss://ws.finnhub.io")
  MAX_WS_SYMBOLS = ENV.fetch("FINNHUB_MAX_WS_SYMBOLS", 50).to_i
  RATE_LIMIT_PER_MIN = ENV.fetch("FINNHUB_RATE_LIMIT_PER_MIN", 60).to_i
end
