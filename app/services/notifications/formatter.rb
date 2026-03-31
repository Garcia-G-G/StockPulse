# frozen_string_literal: true

module Notifications
  class Formatter
    def format(alert_result, channel:)
      raise NotImplementedError, "Formatter#format not yet implemented"
    end
  end
end
