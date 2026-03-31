# frozen_string_literal: true

class WeeklyReportJob < ApplicationJob
  queue_as :low

  def perform
    raise NotImplementedError, "WeeklyReportJob#perform not yet implemented"
  end
end
