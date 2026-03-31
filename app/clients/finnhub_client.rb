# frozen_string_literal: true

class FinnhubClient < BaseClient
  def initialize
    super(
      base_url: "https://finnhub.io/api/v1",
      rate_limit_key: "finnhub",
      rate_limit_max: FinnhubConfig::RATE_LIMIT_PER_MIN,
      rate_limit_period: 60
    )
  end

  def quote(symbol)
    get("/quote", symbol: symbol, token: api_key)
  end

  def company_profile(symbol)
    get("/stock/profile2", symbol: symbol, token: api_key)
  end

  def financials(symbol)
    get("/stock/metric", symbol: symbol, metric: "all", token: api_key)
  end

  def news(symbol, from: 7.days.ago.strftime("%Y-%m-%d"), to: Date.today.strftime("%Y-%m-%d"))
    get("/company-news", symbol: symbol, from: from, to: to, token: api_key)
  end

  def search(query)
    get("/search", q: query, token: api_key)
  end

  def market_status
    get("/stock/market-status", exchange: "US", token: api_key)
  end

  private

  def api_key
    FinnhubConfig::API_KEY
  end
end
