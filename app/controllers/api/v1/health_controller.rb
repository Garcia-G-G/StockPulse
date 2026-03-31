# frozen_string_literal: true

module Api
  module V1
    class HealthController < BaseController
      def show
        checks = {
          status: "ok",
          timestamp: Time.current.iso8601,
          database: database_healthy?,
          redis: redis_healthy?,
          sidekiq: sidekiq_healthy?
        }
        status = checks.values_at(:database, :redis, :sidekiq).all? ? :ok : :service_unavailable
        render json: checks, status: status
      end

      def metrics
        render json: {
          watchlist_items: WatchlistItem.active.count,
          active_alerts: Alert.enabled.count,
          alerts_triggered_today: AlertHistory.today.count,
          price_snapshots: PriceSnapshot.count,
          sidekiq_queues: Sidekiq::Stats.new.queues
        }
      end

      private

      def database_healthy?
        ActiveRecord::Base.connection.execute("SELECT 1")
        true
      rescue StandardError
        false
      end

      def redis_healthy?
        REDIS_POOL.with { |r| r.ping == "PONG" }
      rescue StandardError
        false
      end

      def sidekiq_healthy?
        Sidekiq::Stats.new.processes_size > 0
      rescue StandardError
        false
      end
    end
  end
end
