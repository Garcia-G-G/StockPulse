# frozen_string_literal: true

class DailySummaryJob < ApplicationJob
  queue_as :default

  def perform
    User.active.find_each do |user|
      alerts_today = user.alert_histories.today.recent
      watchlist = user.watchlist_items.active

      summary = build_summary(user, watchlist, alerts_today)

      if user.email.present?
        AlertMailer.daily_summary(user: user, summary_data: summary).deliver_later
      end

      SendNotificationJob.perform_later(user_id: user.id, message: format_summary(summary))
    rescue StandardError => e
      SystemLog.log(level: "error", component: "daily_summary", message: "Failed for user #{user.id}: #{e.message}")
    end
  end

  private

  def build_summary(user, watchlist, alerts_today)
    {
      date: Date.today,
      watchlist_count: watchlist.count,
      alerts_triggered: alerts_today.count,
      alerts: alerts_today.limit(10).map { |ah| { symbol: ah.symbol, type: ah.alert_type, message: ah.message } }
    }
  end

  def format_summary(summary)
    lines = ["*Daily Summary - #{summary[:date].strftime('%B %d, %Y')}*", ""]
    lines << "Watchlist: #{summary[:watchlist_count]} symbols"
    lines << "Alerts triggered today: #{summary[:alerts_triggered]}"

    if summary[:alerts].any?
      lines << ""
      lines << "*Recent alerts:*"
      summary[:alerts].each { |a| lines << "- #{a[:symbol]}: #{a[:message]}" }
    end

    lines << ""
    lines << "_This is not financial advice._"
    lines.join("\n")
  end
end
