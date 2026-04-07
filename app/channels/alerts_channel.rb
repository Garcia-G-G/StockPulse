# frozen_string_literal: true

class AlertsChannel < ApplicationCable::Channel
  def subscribed
    user_id = params[:user_id]

    if user_id.present? && User.exists?(id: user_id)
      # NOTE: In production, verify that the connected user matches user_id
      # via connection.current_user (requires WebSocket authentication).
      # Currently ActionCable connections are unauthenticated, so any client
      # can subscribe to any user's alerts. See ApplicationCable::Connection.
      stream_from "alerts:#{user_id}"
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
