# frozen_string_literal: true

class PriceSnapshotJob < ApplicationJob
  queue_as :default

  def perform(symbol)
    raise NotImplementedError, "PriceSnapshotJob#perform not yet implemented"
  end
end
