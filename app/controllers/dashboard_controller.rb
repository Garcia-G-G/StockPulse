# frozen_string_literal: true

class DashboardController < ApplicationController
  def index
    @watchlist_items = WatchlistItem.active.includes(:user).limit(50)
    @active_alerts = Alert.active.count
    @alerts_today = AlertHistory.today.count
    @total_users = User.active.count
    @recent_alerts = AlertHistory.recent.limit(10).includes(:alert)
    @system_healthy = system_healthy?
  end

  private

  def system_healthy?
    ActiveRecord::Base.connection.execute("SELECT 1")
    true
  rescue StandardError
    false
  end
end
