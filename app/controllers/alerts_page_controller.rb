# frozen_string_literal: true

class AlertsPageController < ApplicationController
  before_action :authenticate_user!

  def index
    @alerts = current_user.alerts.order(active: :desc, created_at: :desc)
    @recent_history = current_user.alert_histories
                                  .includes(:alert)
                                  .order(triggered_at: :desc)
                                  .limit(20)
    @has_telegram = current_user.telegram_chat_id.present?
    @has_whatsapp = current_user.whatsapp_number.present?
  end
end
