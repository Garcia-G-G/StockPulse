# frozen_string_literal: true

namespace :stream do
  desc "Start the Finnhub WebSocket price streaming pipeline"
  task start: :environment do
    manager = Streaming::PriceStreamManager.new

    %w[INT TERM].each do |signal|
      Signal.trap(signal) do
        puts "\nShutting down stream manager..."
        manager.stop
        exit(0)
      end
    end

    puts "Starting Finnhub price stream..."
    manager.start
  end
end
