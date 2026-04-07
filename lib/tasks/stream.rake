# frozen_string_literal: true

namespace :stream do
  desc "Start the real-time price streaming pipeline (Alpaca + Finnhub)"
  task start: :environment do
    manager = Streaming::PriceStreamManager.new

    %w[INT TERM].each do |signal|
      Signal.trap(signal) do
        puts "\nShutting down stream manager..."
        manager.stop
        exit(0)
      end
    end

    puts "Starting dual-source price stream (Alpaca primary, Finnhub secondary)..."
    manager.start

    loop { sleep(1) }
  end
end
