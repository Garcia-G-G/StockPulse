# frozen_string_literal: true

module Alerts
  class NewsEvaluator
    def evaluate(alert, news_data:, **_opts)
      raise NotImplementedError, "NewsEvaluator#evaluate not yet implemented"
    end
  end
end
