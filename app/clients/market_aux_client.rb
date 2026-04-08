# frozen_string_literal: true

class MarketAuxClient < BaseClient
  def initialize
    super(
      base_url: "https://api.marketaux.com/v1",
      rate_limit_key: "marketaux",
      rate_limit_max: 100,
      rate_limit_period: 86_400
    )
  end

  def news(symbols:, limit: 10, language: "en")
    get("/news/all", {
      symbols: Array(symbols).join(","),
      filter_entities: true,
      language: language,
      limit: limit,
      api_token: api_key
    })
  end

  private

  def api_key
    key = ENV.fetch("MARKETAUX_API_KEY", "")
    raise "MARKETAUX_API_KEY not configured" if key.blank?

    key
  end
end
