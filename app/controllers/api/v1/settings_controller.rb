# frozen_string_literal: true

module Api
  module V1
    class SettingsController < BaseController
      def show
        render json: {
          notification_preferences: current_user.notification_preferences,
          muted: current_user.muted?,
          muted_until: current_user.muted_until,
          timezone: current_user.timezone
        }
      end

      def update
        current_user.update!(settings_params)
        render json: { notification_preferences: current_user.notification_preferences }
      end

      def test_notification
        Notifications::Manager.new.notify(
          user: current_user,
          message: "Test notification from StockPulse!"
        )
        render json: { status: "sent" }
      end

      def mute
        minutes = params.fetch(:minutes, 60).to_i
        current_user.mute!(minutes)
        render json: { muted: true, muted_until: current_user.muted_until }
      end

      def unmute
        current_user.unmute!
        render json: { muted: false }
      end

      private

      def settings_params
        params.require(:user).permit(:timezone, notification_preferences: {})
      end
    end
  end
end
