# frozen_string_literal: true

class MorningBriefingJob < ApplicationJob
  queue_as :default

  def perform
    User.active.find_each do |user|
      watchlist = user.watchlist_items.active.pluck(:symbol)
      next if watchlist.empty?

      briefing = generate_briefing(watchlist)
      SendNotificationJob.perform_later(user_id: user.id, message: briefing)
    rescue StandardError => e
      SystemLog.log(level: "error", component: "morning_briefing", message: "Failed for user #{user.id}: #{e.message}")
    end
  end

  private

  def generate_briefing(symbols)
    client = FinnhubClient.new
    lines = ["*Morning Briefing - #{Date.today.strftime('%B %d, %Y')}*", ""]

    symbols.first(10).each do |symbol|
      begin
        quote = client.quote(symbol)
        price = quote["c"]
        change = quote["dp"]
        emoji = change.to_f.positive? ? "+" : ""
        lines << "#{symbol}: $#{'%.2f' % price} (#{emoji}#{'%.2f' % change}%)"
      rescue BaseClient::RateLimitExceeded
        lines << "#{symbol}: rate limited"
        break
      rescue Faraday::Error
        lines << "#{symbol}: unavailable"
      end
    end

    lines << ""
    lines << "_This is not financial advice._"
    lines.join("\n")
  end
end
