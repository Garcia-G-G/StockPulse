# frozen_string_literal: true

module Alerts
  class MultiConditionEvaluator
    SubAlert = Struct.new(:symbol, :alert_type, :condition, keyword_init: true)

    EVALUATOR_MAP = {
      "price" => "Alerts::PriceEvaluator",
      "technical" => "Alerts::TechnicalEvaluator",
      "volume" => "Alerts::VolumeEvaluator",
      "news" => "Alerts::NewsEvaluator"
    }.freeze

    def evaluate(alert, price_data:, technical_data: nil, news_data: nil, **_opts)
      conditions = alert.condition&.dig("conditions")
      return nil unless conditions.is_a?(Array) && conditions.any?

      operator = (alert.condition&.dig("operator") || "AND").upcase
      results = conditions.filter_map do |cond|
        evaluate_sub(alert, cond, price_data: price_data, technical_data: technical_data, news_data: news_data)
      end

      triggered = if operator == "AND"
        results.size == conditions.size && results.all? { |r| r[:triggered] }
      else
        results.any? { |r| r[:triggered] }
      end

      return nil unless triggered

      messages = results.select { |r| r[:triggered] }.map { |r| r[:message] }
      {
        triggered: true,
        message: "#{alert.symbol} multi-condition (#{operator}): #{messages.join(' | ')}",
        data: { operator: operator, sub_results: results }
      }
    end

    private

    def evaluate_sub(alert, condition, price_data:, technical_data:, news_data:)
      evaluator_class = EVALUATOR_MAP[condition["type"]]&.constantize
      return nil unless evaluator_class

      sub_alert = SubAlert.new(symbol: alert.symbol, alert_type: condition["alert_type"], condition: condition)
      evaluator_class.new.evaluate(sub_alert, price_data: price_data, technical_data: technical_data, news_data: news_data)
    end
  end
end
