# frozen_string_literal: true

module Alerts
  class Engine
    EVALUATORS = {
      "price_above" => "Alerts::PriceEvaluator",
      "price_below" => "Alerts::PriceEvaluator",
      "price_change_pct" => "Alerts::PriceEvaluator",
      "rsi_overbought" => "Alerts::TechnicalEvaluator",
      "rsi_oversold" => "Alerts::TechnicalEvaluator",
      "macd_crossover" => "Alerts::TechnicalEvaluator",
      "bollinger_breakout" => "Alerts::TechnicalEvaluator",
      "volume_spike" => "Alerts::VolumeEvaluator",
      "news_sentiment" => "Alerts::NewsEvaluator",
      "multi_condition" => "Alerts::MultiConditionEvaluator"
    }.freeze

    def evaluate_all(symbol:, price_data:, technical_data: nil, news_data: nil)
      alerts = Alert.active_alerts.for_symbol(symbol)

      alerts.filter_map do |alert|
        next if alert.cooldown_active?

        evaluate_alert(alert, price_data: price_data, technical_data: technical_data, news_data: news_data)
      end
    end

    private

    def evaluate_alert(alert, price_data:, technical_data:, news_data:)
      evaluator_class = EVALUATORS[alert.alert_type]&.constantize
      return unless evaluator_class

      evaluator = evaluator_class.new
      result = evaluator.evaluate(alert, price_data: price_data, technical_data: technical_data, news_data: news_data)
      return unless result&.dig(:triggered)

      alert.record_trigger!
      result.merge(alert: alert)
    end
  end
end
