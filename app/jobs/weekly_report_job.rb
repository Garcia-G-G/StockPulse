# frozen_string_literal: true

class WeeklyReportJob < ApplicationJob
  queue_as :low

  def perform
    User.active.find_each do |user|
      watchlist_symbols = user.watchlist_items.active.pluck(:symbol)
      next if watchlist_symbols.empty?

      report = build_report(user, watchlist_symbols)
      SendNotificationJob.perform_later(user_id: user.id, message: format_report(report))
    rescue StandardError => e
      SystemLog.log(level: "error", component: "weekly_report", message: "Failed for user #{user.id}: #{e.message}")
    end
  end

  private

  def build_report(user, symbols)
    week_start = 7.days.ago
    alerts = user.alert_histories.where("triggered_at >= ?", week_start).count
    performers = symbols.filter_map { |sym| weekly_performance(sym) }

    {
      week_ending: Date.today,
      total_alerts: alerts,
      top_gainers: performers.sort_by { |p| -p[:change] }.first(3),
      top_losers: performers.sort_by { |p| p[:change] }.first(3)
    }
  end

  def weekly_performance(symbol)
    current = PriceSnapshot.for_symbol(symbol).recent.first
    week_ago = PriceSnapshot.for_symbol(symbol).where("captured_at < ?", 7.days.ago).recent.first
    return nil unless current && week_ago && week_ago.price.positive?

    change = ((current.price - week_ago.price) / week_ago.price * 100).round(2)
    { symbol: symbol, price: current.price.to_f, change: change }
  end

  def format_report(report)
    lines = ["*Weekly Report - Week ending #{report[:week_ending].strftime('%B %d, %Y')}*", ""]
    lines << "Total alerts this week: #{report[:total_alerts]}"

    if report[:top_gainers].any?
      lines << ""
      lines << "*Top Gainers:*"
      report[:top_gainers].each { |p| lines << "+#{'%.2f' % p[:change]}% #{p[:symbol]} ($#{'%.2f' % p[:price]})" }
    end

    if report[:top_losers].any?
      lines << ""
      lines << "*Top Losers:*"
      report[:top_losers].each { |p| lines << "#{'%.2f' % p[:change]}% #{p[:symbol]} ($#{'%.2f' % p[:price]})" }
    end

    lines << ""
    lines << "_This is not financial advice._"
    lines.join("\n")
  end
end
