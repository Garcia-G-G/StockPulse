# frozen_string_literal: true

class AiServiceClient < BaseClient
  def initialize
    super(
      base_url: ENV.fetch("AI_SERVICE_URL", "http://localhost:8001")
    )
  end

  def analyze(symbol:, price_data:, technical_data:, news_data:)
    post("/analyze", {
      symbol: symbol,
      price_data: price_data,
      technical_data: technical_data,
      news_data: news_data
    })
  end

  def health
    get("/health")
  end
end
