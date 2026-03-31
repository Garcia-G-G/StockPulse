# frozen_string_literal: true

module Alerts
  class TechnicalEvaluator
    INDICATOR_STALENESS = 30.minutes
    STATE_TTL = 3600

    def evaluate(alert, price_data:, **_opts)
      indicators = cached_indicators(alert.symbol)
      return stale_warning(alert) unless indicators_fresh?(indicators)

      current_price = price_data[:close]&.to_f
      condition = alert.condition.deep_symbolize_keys

      result = case alert.alert_type
      when "rsi_overbought" then evaluate_rsi_cross(:above, alert, indicators, condition)
      when "rsi_oversold" then evaluate_rsi_cross(:below, alert, indicators, condition)
      when "macd_crossover_bullish" then evaluate_macd_cross(:bullish, alert, indicators)
      when "macd_crossover_bearish" then evaluate_macd_cross(:bearish, alert, indicators)
      when "bollinger_break_upper" then evaluate_bollinger(:upper, alert, current_price, indicators)
      when "bollinger_break_lower" then evaluate_bollinger(:lower, alert, current_price, indicators)
      when "sma_golden_cross" then evaluate_sma_cross(:golden, alert, indicators)
      when "sma_death_cross" then evaluate_sma_cross(:death, alert, indicators)
      end

      result
    end

    private

    # --- RSI ---

    def evaluate_rsi_cross(direction, alert, indicators, condition)
      rsi = indicators.dig(:rsi, :value)&.to_f
      return unless rsi

      threshold = condition[:threshold]&.to_f || (direction == :above ? 70.0 : 30.0)
      last_rsi = read_state(alert.id, :rsi)&.to_f
      store_state(alert.id, :rsi, rsi)

      return unless last_rsi

      crossed = case direction
      when :above then last_rsi < threshold && rsi >= threshold
      when :below then last_rsi > threshold && rsi <= threshold
      end

      return unless crossed

      label = direction == :above ? "overbought" : "oversold"
      {
        triggered: true,
        message: "RSI crossed #{label} threshold #{threshold} (now #{rsi.round(2)})",
        previous_price: nil,
        indicator_values: { rsi: rsi, threshold: threshold, previous_rsi: last_rsi }
      }
    end

    # --- MACD ---

    def evaluate_macd_cross(direction, alert, indicators)
      macd_line = indicators.dig(:macd, :macd_line)&.to_f
      signal_line = indicators.dig(:macd, :signal_line)&.to_f
      return unless macd_line && signal_line

      last_macd = read_state(alert.id, :macd_line)&.to_f
      last_signal = read_state(alert.id, :signal_line)&.to_f
      store_state(alert.id, :macd_line, macd_line)
      store_state(alert.id, :signal_line, signal_line)

      return unless last_macd && last_signal

      crossed = case direction
      when :bullish then last_macd <= last_signal && macd_line > signal_line
      when :bearish then last_macd >= last_signal && macd_line < signal_line
      end

      return unless crossed

      label = direction == :bullish ? "bullish" : "bearish"
      {
        triggered: true,
        message: "MACD #{label} crossover (MACD: #{macd_line.round(4)}, Signal: #{signal_line.round(4)})",
        previous_price: nil,
        indicator_values: { macd_line: macd_line, signal_line: signal_line }
      }
    end

    # --- Bollinger Bands ---

    def evaluate_bollinger(band, alert, current_price, indicators)
      return unless current_price&.positive?

      upper = indicators.dig(:bollinger, :upper)&.to_f
      lower = indicators.dig(:bollinger, :lower)&.to_f
      return unless upper && lower

      last_price = read_state(alert.id, :bb_price)&.to_f
      store_state(alert.id, :bb_price, current_price)

      return unless last_price

      crossed = case band
      when :upper then last_price <= upper && current_price > upper
      when :lower then last_price >= lower && current_price < lower
      end

      return unless crossed

      band_value = band == :upper ? upper : lower
      {
        triggered: true,
        message: "Price broke #{band} Bollinger Band at $#{band_value.round(2)} (now $#{current_price})",
        previous_price: last_price,
        indicator_values: { bollinger_upper: upper, bollinger_lower: lower }
      }
    end

    # --- SMA Cross ---

    def evaluate_sma_cross(cross_type, alert, indicators)
      sma50 = indicators.dig(:sma50, :value)&.to_f
      sma200 = indicators.dig(:sma200, :value)&.to_f
      return unless sma50 && sma200

      last_sma50 = read_state(alert.id, :sma50)&.to_f
      last_sma200 = read_state(alert.id, :sma200)&.to_f
      store_state(alert.id, :sma50, sma50)
      store_state(alert.id, :sma200, sma200)

      return unless last_sma50 && last_sma200

      crossed = case cross_type
      when :golden then last_sma50 <= last_sma200 && sma50 > sma200
      when :death then last_sma50 >= last_sma200 && sma50 < sma200
      end

      return unless crossed

      label = cross_type == :golden ? "Golden Cross" : "Death Cross"
      {
        triggered: true,
        message: "#{label}: 50-SMA ($#{sma50.round(2)}) crossed #{cross_type == :golden ? 'above' : 'below'} 200-SMA ($#{sma200.round(2)})",
        previous_price: nil,
        indicator_values: { sma50: sma50, sma200: sma200 }
      }
    end

    # --- Indicator Data ---

    def cached_indicators(symbol)
      raw = REDIS_POOL.with { |r| r.get("indicators:#{symbol.upcase}") }
      return {} unless raw

      JSON.parse(raw, symbolize_names: true)
    rescue JSON::ParserError
      {}
    end

    def indicators_fresh?(indicators)
      updated_at = indicators[:updated_at]
      return false unless updated_at

      Time.parse(updated_at.to_s) > INDICATOR_STALENESS.ago
    rescue ArgumentError
      false
    end

    def stale_warning(alert)
      Rails.logger.warn("[TechnicalEvaluator] Stale indicators for #{alert.symbol}, skipping alert #{alert.id}")
      nil
    end

    # --- Redis State ---

    def read_state(alert_id, key)
      REDIS_POOL.with { |r| r.get("alert_state:#{alert_id}:#{key}") }
    end

    def store_state(alert_id, key, value)
      REDIS_POOL.with { |r| r.setex("alert_state:#{alert_id}:#{key}", STATE_TTL, value.to_s) }
    end
  end
end
