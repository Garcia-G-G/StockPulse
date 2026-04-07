# frozen_string_literal: true

class DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :require_onboarding

  def index
    @user = current_user
    @watchlist_items = current_user.watchlist_items.active
    @active_alerts = current_user.alerts.active.count
    @alerts_today = current_user.alert_histories.where("triggered_at >= ?", Time.current.beginning_of_day).count
    @recent_alerts = current_user.alert_histories.order(triggered_at: :desc).limit(10).includes(:alert)
    @system_healthy = system_healthy?
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
