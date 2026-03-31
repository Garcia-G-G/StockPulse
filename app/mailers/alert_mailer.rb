# frozen_string_literal: true

class AlertMailer < ApplicationMailer
  def price_alert(user:, alert:, price_data:, ai_analysis: nil, email_data: nil, subject: nil)
    @user = user
    @alert = alert
    @price_data = price_data
    @ai_analysis = ai_analysis
    @email_data = email_data || {}

    mail(
      to: user.email,
      subject: subject || "[StockPulse] #{alert.symbol}: #{alert.alert_type}"
    )
  end

  def daily_summary(user:, summary_data:)
    @user = user
    @summary_data = summary_data

    mail(
      to: user.email,
      subject: "[StockPulse] Resumen Diario \u{2014} #{Date.current.strftime('%d de %B, %Y')}"
    )
  end
end
