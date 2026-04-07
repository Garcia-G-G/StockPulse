# frozen_string_literal: true

class StatusChannel < ApplicationCable::Channel
  def subscribed
    stream_from "system:status"
  end

  def unsubscribed
    stop_all_streams
  end

  def self.broadcast_status
    cache = Streaming::RedisPriceCache.new
    stats = cache.get_stats

    ActionCable.server.broadcast("system:status", {
      alpaca_status: cache.get_connection_status("alpaca"),
      finnhub_status: cache.get_connection_status("finnhub"),
      symbols_count: stats["symbols_count"] || 0,
      trades_per_second: stats["trades_per_second"] || 0,
      uptime_seconds: stats["uptime_seconds"] || 0,
      timestamp: Time.current.iso8601
    })
  end
end
