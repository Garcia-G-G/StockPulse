# frozen_string_literal: true

class SyncSubscriptionsJob < ApplicationJob
  queue_as :streaming

  def perform
    raise NotImplementedError, "SyncSubscriptionsJob#perform not yet implemented"
  end
end
