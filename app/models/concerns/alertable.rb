# frozen_string_literal: true

module Alertable
  extend ActiveSupport::Concern

  included do
    scope :active_alerts, -> { where(active: true) }
    scope :for_symbol, ->(symbol) { where(symbol: symbol.upcase) }
  end

  def cooldown_active?
    return false unless last_triggered_at

    last_triggered_at > cooldown_minutes.minutes.ago
  end

  def record_trigger!
    update!(
      last_triggered_at: Time.current,
      trigger_count: (trigger_count || 0) + 1
    )
  end
end
