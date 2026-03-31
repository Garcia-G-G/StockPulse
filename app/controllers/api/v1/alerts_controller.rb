# frozen_string_literal: true

module Api
  module V1
    class AlertsController < BaseController
      def index
        alerts = current_user.alerts.active
        render json: AlertSerializer.new(alerts).serializable_hash
      end

      def create
        alert = current_user.alerts.create!(alert_params)
        render json: AlertSerializer.new(alert).serializable_hash, status: :created
      end

      def update
        alert = current_user.alerts.find(params[:id])
        alert.update!(alert_params)
        render json: AlertSerializer.new(alert).serializable_hash
      end

      def destroy
        alert = current_user.alerts.find(params[:id])
        alert.destroy!
        head :no_content
      end

      def history
        @pagy, histories = pagy(current_user.alert_histories.recent, items: 20)
        render json: AlertHistorySerializer.new(histories).serializable_hash
      end

      private

      def alert_params
        params.require(:alert).permit(:symbol, :alert_type, :cooldown_minutes, :active, condition: {}, channels: [])
      end
    end
  end
end
