# frozen_string_literal: true

class MorningBriefingJob < ApplicationJob
  queue_as :default

  def perform
    raise NotImplementedError, "MorningBriefingJob#perform not yet implemented"
  end
end
