# frozen_string_literal: true

module Alerts
  class TechnicalEvaluator
    def evaluate(alert, technical_data:, **_opts)
      raise NotImplementedError, "TechnicalEvaluator#evaluate not yet implemented"
    end
  end
end
