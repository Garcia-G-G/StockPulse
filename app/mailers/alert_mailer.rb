# frozen_string_literal: true

class AlertMailer < ApplicationMailer
  def price_alert(user:, alert:, data:)
    @user = user
    @alert = alert
    @data = data
    mail(to: user.email, subject: "StockPulse Alert: #{alert.symbol} #{alert.alert_type}")
  end

  def daily_summary(user:, summary_data:)
    @user = user
    @summary_data = summary_data
    mail(to: user.email, subject: "StockPulse Daily Summary - #{Date.today.strftime('%B %d, %Y')}")
  end
end
