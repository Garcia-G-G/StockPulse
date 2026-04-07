# frozen_string_literal: true

module Alerts
  class TechnicalEvaluator
    def evaluate(alert, price_data:, technical_data: nil, **_opts)
      return nil unless technical_data

      case alert.alert_type
      when "rsi_overbought"
        check_rsi(alert, technical_data, :overbought)
      when "rsi_oversold"
        check_rsi(alert, technical_data, :oversold)
      when "macd_crossover"
        check_macd_crossover(alert, technical_data)
      when "bollinger_breakout"
        check_bollinger_breakout(alert, technical_data, price_data)
      end
    end

    private

    def check_rsi(alert, technical_data, direction)
      rsi = extract_rsi(technical_data)
      return nil unless rsi

      threshold = (alert.condition&.dig("value") || (direction == :overbought ? 70 : 30)).to_f
      triggered = direction == :overbought ? rsi > threshold : rsi < threshold
      return nil unless triggered

      {
        triggered: true,
        message: "#{alert.symbol} RSI at #{'%.1f' % rsi} (#{direction} #{direction == :overbought ? '>' : '<'} #{'%.0f' % threshold})",
        data: { rsi: rsi, threshold: threshold, signal: direction.to_s }
      }
    end

    def check_macd_crossover(alert, technical_data)
      macd = technical_data["macd"] || technical_data[:macd]
      return nil unless macd.is_a?(Hash)

      histogram = (macd["MACD_Hist"] || macd["histogram"]).to_f
      prev_histogram = (macd["MACD_Hist_Prev"] || macd["prev_histogram"]).to_f
      return nil if prev_histogram.zero? && histogram.zero?

      bullish = prev_histogram < 0 && histogram >= 0
      bearish = prev_histogram > 0 && histogram <= 0
      return nil unless bullish || bearish

      direction = bullish ? "bullish" : "bearish"
      macd_val = (macd["MACD"] || macd["macd"]).to_f
      signal_val = (macd["MACD_Signal"] || macd["signal"]).to_f

      {
        triggered: true,
        message: "#{alert.symbol} MACD #{direction} crossover (MACD: #{'%.4f' % macd_val}, Signal: #{'%.4f' % signal_val})",
        data: { macd: macd_val, signal: signal_val, histogram: histogram, crossover: direction }
      }
    end

    def check_bollinger_breakout(alert, technical_data, price_data)
      bb = technical_data["bollinger"] || technical_data[:bollinger]
      return nil unless bb.is_a?(Hash)

      price = (price_data[:price] || price_data["price"] || price_data["c"]).to_f
      upper = (bb["Real Upper Band"] || bb["upper"]).to_f
      lower = (bb["Real Lower Band"] || bb["lower"]).to_f
      return nil unless upper.positive? && lower.positive?

      if price > upper
        { triggered: true, message: "#{alert.symbol} broke above Bollinger upper band ($#{'%.2f' % price} > $#{'%.2f' % upper})",
          data: { price: price, upper: upper, lower: lower, breakout: "above" } }
      elsif price < lower
        { triggered: true, message: "#{alert.symbol} broke below Bollinger lower band ($#{'%.2f' % price} < $#{'%.2f' % lower})",
          data: { price: price, upper: upper, lower: lower, breakout: "below" } }
      end
    end

    def extract_rsi(data)
      rsi_data = data["rsi"] || data[:rsi]
      return nil unless rsi_data

      rsi_data.is_a?(Hash) ? rsi_data.values.first.to_f : rsi_data.to_f
    end
  end
end
