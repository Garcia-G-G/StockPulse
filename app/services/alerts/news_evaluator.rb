# frozen_string_literal: true

module Alerts
  class NewsEvaluator
    def evaluate(alert, news_data:, **_opts)
      return unless news_data.is_a?(Hash)

      condition = alert.condition.deep_symbolize_keys
      min_score = condition[:min_sentiment_score]&.to_f
      return unless min_score

      sentiment_score = news_data[:sentiment_score]&.to_f
      return unless sentiment_score

      return unless sentiment_score.abs >= min_score

      headline = news_data[:title] || news_data[:headline] || "Unknown headline"
      source = news_data[:source] || "Unknown"

      {
        triggered: true,
        message: "High-impact news for #{alert.symbol}: \"#{headline}\" (sentiment: #{sentiment_score}, source: #{source})",
        previous_price: nil,
        indicator_values: {
          sentiment_score: sentiment_score,
          headline: headline,
          source: source,
          min_sentiment_score: min_score
        }
      }
    end
  end
end
