# frozen_string_literal: true

module Alerts
  class NewsEvaluator
    SENTIMENT_THRESHOLDS = { positive: 0.6, negative: -0.6 }.freeze

    def evaluate(alert, news_data:, **_opts)
      return nil unless news_data.is_a?(Hash)

      articles = news_data["data"] || news_data[:data] || []
      return nil if articles.empty?

      significant = articles.select { |a| significant_article?(a) }
      return nil if significant.empty?

      top = significant.first
      sentiment = extract_sentiment(top)
      headline = top["title"] || top[:title] || "Breaking news"

      {
        triggered: true,
        message: "#{alert.symbol} news: #{headline} (sentiment: #{sentiment})",
        data: {
          headline: headline,
          sentiment: sentiment,
          url: top["url"] || top[:url],
          article_count: significant.size
        }
      }
    end

    private

    def significant_article?(article)
      entities = article["entities"] || article[:entities] || []
      return true if entities.any?

      (article["relevance_score"] || article[:relevance_score]).to_f > 0.5
    end

    def extract_sentiment(article)
      entities = article["entities"] || article[:entities] || []
      score = entities.filter_map { |e| (e["sentiment_score"] || e[:sentiment_score])&.to_f }.first || 0

      if score > SENTIMENT_THRESHOLDS[:positive]
        "positive"
      elsif score < SENTIMENT_THRESHOLDS[:negative]
        "negative"
      else
        "neutral"
      end
    end
  end
end
