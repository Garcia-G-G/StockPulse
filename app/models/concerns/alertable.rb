# frozen_string_literal: true

module Alertable
  extend ActiveSupport::Concern

  included do
    scope :enabled, -> { where(is_enabled: true) }
    scope :for_symbol, ->(sym) { where(symbol: sym.upcase) }
  end

  def in_cooldown?
    return false unless last_triggered_at

    last_triggered_at > cooldown_minutes.minutes.ago
  end

  def record_trigger!
    update!(
      last_triggered_at: Time.current,
      trigger_count: trigger_count + 1,
      is_enabled: !should_auto_disable?
    )
  end

  def disable!
    update!(is_enabled: false)
  end

  def price_type?
    Alert::PRICE_TYPES.include?(alert_type)
  end

  def technical_type?
    Alert::TECHNICAL_TYPES.include?(alert_type)
  end

  private

  def should_auto_disable?
    return true if is_one_time
    return true if max_triggers.present? && (trigger_count + 1) >= max_triggers

    false
  end
end
