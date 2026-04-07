# frozen_string_literal: true

module AlpacaConfig
  API_KEY = ENV.fetch("ALPACA_API_KEY", "")
  API_SECRET = ENV.fetch("ALPACA_API_SECRET", "")
  WS_URL = ENV.fetch("ALPACA_WS_URL", "wss://stream.data.alpaca.markets/v2/iex")
  PAPER_MODE = ENV.fetch("ALPACA_PAPER_MODE", "true") == "true"
end
