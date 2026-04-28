# frozen_string_literal: true

module Api
  module V1
    class HealthController < BaseController
      skip_before_action :authenticate_user_or_api!, raise: false

      # Liveness/readiness probe.
      #
      # Critical components (database, redis) failing -> 503.
      # Non-critical components (sidekiq) failing -> 200 with status="degraded"
      # so the app remains reachable when background workers happen to be down.
      def show
        db    = database_healthy?
        redis = redis_healthy?
        sidekiq = sidekiq_healthy?

        critical_ok = db && redis
        all_ok = critical_ok && sidekiq
        status = all_ok ? "ok" : (critical_ok ? "degraded" : "down")

        render json: {
          status: status,
          timestamp: Time.current.iso8601,
          database: db,
          redis: redis,
          sidekiq: sidekiq
        }, status: critical_ok ? :ok : :service_unavailable
      end

      def metrics
        render json: {
          watchlist_items: WatchlistItem.active.count,
          active_alerts: Alert.active.count,
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
