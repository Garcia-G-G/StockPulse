# frozen_string_literal: true

class UpdateIndicatorsJob < ApplicationJob
  queue_as :default

  def perform
    raise NotImplementedError, "UpdateIndicatorsJob#perform not yet implemented"
  end
end
