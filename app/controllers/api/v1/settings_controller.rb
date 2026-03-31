# frozen_string_literal: true

module Api
  module V1
    class SettingsController < BaseController
      def show
        render json: { settings: current_user.settings, notifications_muted: current_user.notifications_muted }
      end

      def update
        current_user.update!(settings_params)
        render json: { settings: current_user.settings }
      end

      def test_notification
        Notifications::Manager.new.notify(
          user: current_user,
          message: "Test notification from StockPulse!"
        )
        render json: { status: "sent" }
      end

      def mute
        current_user.update!(notifications_muted: true)
        render json: { notifications_muted: true }
      end

      def unmute
        current_user.update!(notifications_muted: false)
        render json: { notifications_muted: false }
      end

      private

      def settings_params
        params.require(:settings).permit(settings: {})
      end
    end
  end
end
