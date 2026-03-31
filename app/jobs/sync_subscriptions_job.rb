# frozen_string_literal: true

class SyncSubscriptionsJob < ApplicationJob
  queue_as :streaming

  def perform
    desired = WatchlistItem.all_active_symbols
    current = current_subscriptions

    to_add = desired - current
    to_remove = current - desired

    return if to_add.empty? && to_remove.empty?

    Rails.logger.info("[SyncSubscriptionsJob] Rebalancing: +#{to_add.size} -#{to_remove.size}")

    publish_command({ action: "rebalance" })
  end

  private

  def current_subscriptions
    REDIS_POOL.with { |r| r.smembers("stream:subscriptions") }
  end

  def publish_command(command)
    REDIS_POOL.with do |redis|
      redis.publish("stream:commands", command.to_json)
    end
  end
end
