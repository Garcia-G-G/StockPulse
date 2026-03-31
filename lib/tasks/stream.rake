# frozen_string_literal: true

namespace :stream do
  desc "Start the WebSocket price streaming process"
  task start: :environment do
    manager = Streaming::PriceStreamManager.new
    manager.start
  end
end
