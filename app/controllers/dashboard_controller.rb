# frozen_string_literal: true

class DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :require_onboarding

  def index
    @user = current_user
    # Load the watchlist into memory up front so .size / .any? / .first in
    # the view use Array methods instead of re-issuing COUNT / EXISTS / LIMIT 1.
    @watchlist_items = current_user.watchlist_items.active.order(:created_at).to_a
    @primary_symbol = @watchlist_items.first&.symbol

    @active_alerts = current_user.alerts.active.count
    @alerts_today = current_user.alert_histories
                                .where("triggered_at >= ?", Time.current.beginning_of_day)
                                .count
    @recent_alerts = current_user.alert_histories
                                 .includes(:alert)
                                 .order(triggered_at: :desc)
                                 .limit(15)
                                 .to_a
    @alert_counts_by_symbol = current_user.alerts.active.group(:symbol).count
  end

  private

  def require_onboarding
    redirect_to "/onboarding" unless current_user.onboarding_completed?
  end
end
