# frozen_string_literal: true

module Notifiable
  extend ActiveSupport::Concern

  included do
    scope :not_muted, -> { where(muted_until: nil).or(where(muted_until: ...Time.current)) }
    scope :with_telegram, -> { where.not(telegram_chat_id: nil) }
  end

  def muted?
    muted_until.present? && muted_until > Time.current
  end

  def mute!(minutes)
    update!(muted_until: minutes.minutes.from_now)
  end

  def unmute!
    update!(muted_until: nil)
  end

  def enabled_channels
    prefs = notification_preferences&.deep_symbolize_keys || {}
    channels = []
    channels << :telegram if prefs.dig(:telegram, :enabled) && telegram_chat_id.present?
    channels << :whatsapp if prefs.dig(:whatsapp, :enabled) && whatsapp_number.present?
    channels << :email if prefs.dig(:email, :enabled) && email.present?
    channels
  end

  def in_quiet_hours?
    prefs = notification_preferences&.deep_symbolize_keys || {}
    tz = ActiveSupport::TimeZone[timezone] || ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    now = Time.current.in_time_zone(tz)

    enabled_channels.any? do |channel|
      channel_prefs = prefs[channel] || {}
      quiet_start = channel_prefs[:quiet_start]
      quiet_end = channel_prefs[:quiet_end]
      next false unless quiet_start.present? && quiet_end.present?

      start_time = parse_time_in_zone(quiet_start, tz, now)
      end_time = parse_time_in_zone(quiet_end, tz, now)

      if start_time <= end_time
        now >= start_time && now < end_time
      else
        now >= start_time || now < end_time
      end
    end
  end

  private

  def parse_time_in_zone(time_str, tz, reference_date)
    hour, min = time_str.split(":").map(&:to_i)
    tz.local(reference_date.year, reference_date.month, reference_date.day, hour, min)
  end
end
