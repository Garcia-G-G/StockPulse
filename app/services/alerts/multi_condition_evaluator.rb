# frozen_string_literal: true

module Alerts
  class MultiConditionEvaluator
    def evaluate(alert, price_data:, technical_data:, news_data:, **_opts)
      raise NotImplementedError, "MultiConditionEvaluator#evaluate not yet implemented"
    end
  end
end
