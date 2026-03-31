# frozen_string_literal: true

class MarketAuxClient < BaseClient
  def initialize
    super(
      api_name: "market_aux",
      base_url: "https://api.marketaux.com/v1",
      rate_limit: ENV.fetch("MARKETAUX_RATE_LIMIT_PER_DAY", 100).to_i,
      rate_period: 86_400
    )
  end

  def news(symbols: nil, limit: 10)
    params = { limit: limit, api_token: api_key }
    params[:symbols] = Array(symbols).join(",") if symbols.present?

    cached_get("/news/all", params, ttl: 900)
  end

  def news_for_symbol(symbol, limit: 5)
    news(symbols: symbol, limit: limit)
  end

  def sentiment_summary(symbol)
    response = news_for_symbol(symbol, limit: 10)
    articles = response.is_a?(Hash) ? (response[:data] || []) : []

    scores = articles.filter_map { |a| extract_sentiment_score(a, symbol) }

    positive = scores.count { |s| s > 0.1 }
    negative = scores.count { |s| s < -0.1 }
    neutral = scores.count { |s| s.between?(-0.1, 0.1) }
    average = scores.any? ? (scores.sum / scores.size).round(4) : 0.0
    headlines = articles.map { |a| a[:title] }.compact.first(5)

    {
      average_score: average,
      positive_count: positive,
      negative_count: negative,
      neutral_count: neutral,
      headlines: headlines
    }
  end

  private

  def extract_sentiment_score(article, symbol)
    entities = article[:entities] || []
    entity = entities.find { |e| e[:symbol] == symbol.upcase }
    entity&.dig(:sentiment_score)&.to_f
  end

  def api_key
    ENV.fetch("MARKETAUX_API_KEY", "")
  end
end
