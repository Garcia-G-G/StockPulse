# frozen_string_literal: true

class CheckNewsJob < ApplicationJob
  queue_as :default

  def perform
    raise NotImplementedError, "CheckNewsJob#perform not yet implemented"
  end
end
