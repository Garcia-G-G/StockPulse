# frozen_string_literal: true

module Alerts
  class VolumeEvaluator
    def evaluate(alert, price_data:, **_opts)
      current_volume = (price_data[:volume] || price_data["volume"]).to_i
      return nil unless current_volume.positive?

      threshold_pct = (alert.condition&.dig("value") || 200).to_f
      avg_volume = average_volume(alert.symbol)
      return nil unless avg_volume&.positive?

      ratio = (current_volume.to_f / avg_volume) * 100
      return nil unless ratio >= threshold_pct

      {
        triggered: true,
        message: "#{alert.symbol} volume spike: #{format_number(current_volume)} (#{'%.0f' % ratio}% of 20-day avg #{format_number(avg_volume)})",
        data: { volume: current_volume, avg_volume: avg_volume.round, ratio_pct: ratio.round(1) }
      }
    end

    private

    def average_volume(symbol)
      PriceSnapshot.for_symbol(symbol)
                   .where("captured_at > ?", 20.days.ago)
                   .where("volume > 0")
                   .average(:volume)&.to_f
    end

    def format_number(num)
      if num >= 1_000_000
        "#{'%.1f' % (num / 1_000_000.0)}M"
      elsif num >= 1_000
        "#{'%.1f' % (num / 1_000.0)}K"
      else
        num.to_s
      end
    end
  end
end
