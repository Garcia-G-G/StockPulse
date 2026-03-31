# frozen_string_literal: true

module Alerts
  class VolumeEvaluator
    AVG_VOLUME_CACHE_TTL = 3600
    AVG_VOLUME_LOOKBACK = 20

    def evaluate(alert, price_data:, **_opts)
      current_volume = price_data[:volume]&.to_i
      return unless current_volume&.positive?

      condition = alert.condition.deep_symbolize_keys
      threshold_pct = condition[:threshold_percent]&.to_f
      return unless threshold_pct&.positive?

      avg_volume = average_daily_volume(alert.symbol)
      return unless avg_volume&.positive?

      ratio = (current_volume.to_f / avg_volume * 100).round(2)

      case alert.alert_type
      when "volume_spike"
        return unless ratio >= threshold_pct

        {
          triggered: true,
          message: "Volume spike: #{ratio}% of average (threshold: #{threshold_pct}%, current: #{current_volume}, avg: #{avg_volume})",
          previous_price: nil,
          indicator_values: { volume_ratio: ratio, avg_volume: avg_volume, current_volume: current_volume }
        }
      when "volume_dry"
        inverse_ratio = (100.0 - ratio).round(2)
        return unless ratio <= (100.0 - threshold_pct)

        {
          triggered: true,
          message: "Volume dry: #{inverse_ratio}% below average (threshold: #{threshold_pct}%, current: #{current_volume}, avg: #{avg_volume})",
          previous_price: nil,
          indicator_values: { volume_ratio: ratio, avg_volume: avg_volume, current_volume: current_volume }
        }
      end
    end

    private

    def average_daily_volume(symbol)
      cache_key = "avg_volume:#{symbol.upcase}"

      cached = REDIS_POOL.with { |r| r.get(cache_key) }
      return cached.to_f if cached

      snapshots = PriceSnapshot
        .for_symbol(symbol)
        .by_interval("1d")
        .latest_first
        .limit(AVG_VOLUME_LOOKBACK)

      return nil if snapshots.empty?

      avg = snapshots.average(:volume).to_f.round(0)
      REDIS_POOL.with { |r| r.setex(cache_key, AVG_VOLUME_CACHE_TTL, avg.to_s) }
      avg
    end
  end
end
