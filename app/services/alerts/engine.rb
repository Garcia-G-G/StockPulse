# frozen_string_literal: true

module Alerts
  class Engine
    EVALUATORS = {
      "price_above" => "Alerts::PriceEvaluator",
      "price_below" => "Alerts::PriceEvaluator",
      "percent_change_up" => "Alerts::PriceEvaluator",
      "percent_change_down" => "Alerts::PriceEvaluator",
      "price_range_break" => "Alerts::PriceEvaluator",
      "rsi_overbought" => "Alerts::TechnicalEvaluator",
      "rsi_oversold" => "Alerts::TechnicalEvaluator",
      "macd_crossover_bullish" => "Alerts::TechnicalEvaluator",
      "macd_crossover_bearish" => "Alerts::TechnicalEvaluator",
      "bollinger_break_upper" => "Alerts::TechnicalEvaluator",
      "bollinger_break_lower" => "Alerts::TechnicalEvaluator",
      "sma_golden_cross" => "Alerts::TechnicalEvaluator",
      "sma_death_cross" => "Alerts::TechnicalEvaluator",
      "volume_spike" => "Alerts::VolumeEvaluator",
      "volume_dry" => "Alerts::VolumeEvaluator",
      "news_high_impact" => "Alerts::NewsEvaluator"
    }.freeze

    def evaluate_all(symbol:, price_data:, technical_data: nil, news_data: nil)
      alerts = Alert.enabled.for_symbol(symbol)

      alerts.filter_map do |alert|
        next if alert.in_cooldown?

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
