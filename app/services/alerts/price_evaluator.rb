# frozen_string_literal: true

module Alerts
  class PriceEvaluator
    def evaluate(alert, price_data:, **_opts)
      condition = alert.condition || {}
      current_price = (price_data[:price] || price_data["price"] || price_data["c"]).to_f
      return nil unless current_price.positive?

      case alert.alert_type
      when "price_above"
        check_price_above(alert, current_price, condition)
      when "price_below"
        check_price_below(alert, current_price, condition)
      when "price_change_pct"
        check_percent_change(alert, price_data, condition)
      end
    end

    private

    def check_price_above(alert, current_price, condition)
      target = condition["value"].to_f
      return nil unless current_price >= target

      {
        triggered: true,
        message: "#{alert.symbol} reached $#{'%.2f' % current_price} (above $#{'%.2f' % target})",
        data: { price: current_price, target: target, direction: "above" }
      }
    end

    def check_price_below(alert, current_price, condition)
      target = condition["value"].to_f
      return nil unless current_price <= target

      {
        triggered: true,
        message: "#{alert.symbol} dropped to $#{'%.2f' % current_price} (below $#{'%.2f' % target})",
        data: { price: current_price, target: target, direction: "below" }
      }
    end

    def check_percent_change(alert, price_data, condition)
      threshold = condition["value"].to_f
      change_pct = (price_data[:change_percent] || price_data["change_percent"] || price_data["dp"]).to_f
      return nil if change_pct.zero? && threshold != 0

      return nil unless change_pct.abs >= threshold.abs

      direction = change_pct.positive? ? "up" : "down"
      price = (price_data[:price] || price_data["price"] || price_data["c"]).to_f
      {
        triggered: true,
        message: "#{alert.symbol} moved #{direction} #{'%.2f' % change_pct.abs}% (threshold: #{'%.2f' % threshold.abs}%)",
        data: { price: price, change_percent: change_pct, threshold: threshold }
      }
    end
  end
end
