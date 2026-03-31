# frozen_string_literal: true

module Alerts
  class VolumeEvaluator
    def evaluate(alert, price_data:, **_opts)
      raise NotImplementedError, "VolumeEvaluator#evaluate not yet implemented"
    end
  end
end
