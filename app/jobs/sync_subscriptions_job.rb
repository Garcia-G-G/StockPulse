# frozen_string_literal: true

class SyncSubscriptionsJob < ApplicationJob
  queue_as :streaming

  def perform
    symbols = Watchlists::Manager.new.all_watched_symbols

    REDIS_POOL.with do |redis|
      redis.publish("stream:commands", { action: "rebalance", symbols: symbols }.to_json)
    end

    symbols.each do |symbol|
      PriceSnapshotJob.perform_later(symbol)
    end

    SystemLog.log(level: "info", component: "sync_subscriptions", message: "Queued snapshots for #{symbols.size} symbols")
  rescue StandardError => e
    SystemLog.log(level: "error", component: "sync_subscriptions", message: "Failed: #{e.message}")
  end
end
