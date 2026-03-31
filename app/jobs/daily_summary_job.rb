# frozen_string_literal: true

class DailySummaryJob < ApplicationJob
  queue_as :default

  def perform
    raise NotImplementedError, "DailySummaryJob#perform not yet implemented"
  end
end
