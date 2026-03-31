# frozen_string_literal: true

class AiServiceClient < BaseClient
  AI_TIMEOUT = 30
  FALLBACK_RESPONSE = { error: true, fallback: true, message: "AI service unavailable" }.freeze

  def initialize
    super(
      api_name: "ai_service",
      base_url: ENV.fetch("AI_SERVICE_URL", "http://localhost:8001"),
      rate_limit: ENV.fetch("AI_SERVICE_RATE_LIMIT", 10).to_i,
      rate_period: 60
    )
  end

  def analyze_price(symbol:, current_price:, previous_close:, change_percent:, indicators: {}, company_profile: {}, recent_news: [])
    safe_post("/analyze/price", {
      symbol: symbol,
      current_price: current_price,
      previous_close: previous_close,
      change_percent: change_percent,
      indicators: indicators,
      company_profile: company_profile,
      recent_news: recent_news
    })
  end

  def analyze_news(symbol:, headline:, summary:, source:, sentiment: nil)
    safe_post("/analyze/news", {
      symbol: symbol,
      headline: headline,
      summary: summary,
      source: source,
      sentiment: sentiment
    })
  end

  def daily_briefing(watchlist:, include_technicals: true, include_macro: true)
    safe_post("/briefing", {
      watchlist: watchlist,
      include_technicals: include_technicals,
      include_macro: include_macro
    })
  end

  def evaluate_importance(alert_type:, symbol:, alert_description:, current_context: {})
    safe_post("/evaluate", {
      alert_type: alert_type,
      symbol: symbol,
      alert_description: alert_description,
      current_context: current_context
    })
  end

  def health
    get("/health")
  rescue StandardError
    FALLBACK_RESPONSE
  end

  private

  def connection
    @connection ||= Faraday.new(url: base_url) do |f|
      f.request :json
      f.options.timeout = AI_TIMEOUT
      f.options.open_timeout = 5
      f.response :json, parser_options: { symbolize_names: true }
      f.response :raise_error
      f.adapter Faraday.default_adapter
    end
  end

  def safe_post(path, body)
    post(path, body)
  rescue RateLimitExceeded, CircuitOpen, ApiError, Faraday::Error => e
    Rails.logger.error("[ai_service] #{path} failed: #{e.message}")
    FALLBACK_RESPONSE.merge(path: path)
  end
end
