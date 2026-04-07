# frozen_string_literal: true

class AlertsChannel < ApplicationCable::Channel
  def subscribed
    if params[:user_id].present?
      stream_from "alerts:#{params[:user_id]}"
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end

  def self.broadcast_alert(user_id, alert_data)
    ActionCable.server.broadcast("alerts:#{user_id}", alert_data)
  end
end
