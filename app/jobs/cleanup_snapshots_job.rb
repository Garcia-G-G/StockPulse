# frozen_string_literal: true

class CleanupSnapshotsJob < ApplicationJob
  queue_as :low

  def perform
    raise NotImplementedError, "CleanupSnapshotsJob#perform not yet implemented"
  end
end
