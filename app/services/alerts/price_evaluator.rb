# frozen_string_literal: true

module Alerts
  class PriceEvaluator
    def evaluate(alert, price_data:, **_opts)
      raise NotImplementedError, "PriceEvaluator#evaluate not yet implemented"
    end
  end
end
