# frozen_string_literal: true

module Alerts
  # Experimental: evaluates alerts with multiple conditions using AND/OR logic.
  # The alert's condition jsonb should contain:
  #   { operator: "AND"|"OR", conditions: [ { type: "price_above", ... }, ... ] }
  class MultiConditionEvaluator
    SUPPORTED_EVALUATORS = {
      "price" => Alerts::PriceEvaluator,
      "technical" => Alerts::TechnicalEvaluator,
      "volume" => Alerts::VolumeEvaluator
    }.freeze

    def evaluate(alert, price_data:, technical_data: nil, news_data: nil, **_opts)
      condition = alert.condition.deep_symbolize_keys
      operator = condition[:operator]&.upcase || "AND"
      sub_conditions = condition[:conditions]

      return unless sub_conditions.is_a?(Array) && sub_conditions.any?

      results = sub_conditions.filter_map do |sub|
        evaluate_sub_condition(alert, sub, price_data: price_data)
      end

      triggered = case operator
      when "AND" then results.size == sub_conditions.size && results.all? { |r| r[:triggered] }
      when "OR" then results.any? { |r| r[:triggered] }
      else false
      end

      return unless triggered

      {
        triggered: true,
        message: "Multi-condition alert (#{operator}): #{results.count { |r| r[:triggered] }}/#{sub_conditions.size} conditions met",
        previous_price: nil,
        indicator_values: { sub_results: results, operator: operator }
      }
    end

    private

    def evaluate_sub_condition(alert, sub, price_data:)
      sub_type = sub[:type]&.to_s
      evaluator_key = if Alert::PRICE_TYPES.include?(sub_type)
                        "price"
      elsif Alert::TECHNICAL_TYPES.include?(sub_type)
                        "technical"
      elsif Alert::VOLUME_TYPES.include?(sub_type)
                        "volume"
      end

      evaluator_class = SUPPORTED_EVALUATORS[evaluator_key]
      return unless evaluator_class

      # Build a temporary alert-like struct with the sub-condition
      sub_alert = alert.dup
      sub_alert.assign_attributes(alert_type: sub_type, condition: sub.except(:type))

      evaluator_class.new.evaluate(sub_alert, price_data: price_data)
    rescue StandardError => e
      Rails.logger.warn("[MultiConditionEvaluator] Sub-condition error: #{e.message}")
      nil
    end
  end
end
