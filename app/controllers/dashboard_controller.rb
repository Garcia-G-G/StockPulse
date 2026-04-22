# frozen_string_literal: true

class DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :require_onboarding

  def index
    @user = current_user
    @watchlist_items = current_user.watchlist_items.active.order(:created_at)
    @active_alerts = current_user.alerts.active.count
    @alerts_today = current_user.alert_histories.where("triggered_at >= ?", Time.current.beginning_of_day).count
    @recent_alerts = current_user.alert_histories.order(triggered_at: :desc).limit(15).includes(:alert)
    @alert_counts_by_symbol = current_user.alerts.active.group(:symbol).count
    @system_healthy = system_healthy?
    @primary_symbol = @watchlist_items.first&.symbol
  end

  private

  def require_onboarding
    redirect_to "/onboarding" unless current_user.onboarding_completed?
  end

  def system_healthy?
    ActiveRecord::Base.connection.execute("SELECT 1")
    true
  rescue StandardError
    false
  end
end
