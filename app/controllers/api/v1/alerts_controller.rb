# frozen_string_literal: true

module Api
  module V1
    class AlertsController < BaseController
      before_action :set_alert, only: %i[show update destroy toggle]

      def index
        scope = current_user.alerts
        scope = scope.where(active: true) if params[:active].to_s == "true"
        scope = scope.where(symbol: params[:symbol].to_s.upcase) if params[:symbol].present?
        render json: scope.order(created_at: :desc).map { |a| serialize_alert(a) }
      end

      def show
        render json: serialize_alert(@alert)
      end

      def create
        alert = current_user.alerts.build(alert_params)
        unless valid_condition?(alert)
          return render json: { error: "Invalid condition for this alert type",
                                details: condition_help(alert.alert_type) },
                        status: :unprocessable_entity
        end

        if alert.save
          render json: serialize_alert(alert), status: :created
        else
          render json: { error: alert.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def update
        @alert.assign_attributes(alert_params)
        unless valid_condition?(@alert)
          return render json: { error: "Invalid condition for this alert type",
                                details: condition_help(@alert.alert_type) },
                        status: :unprocessable_entity
        end

        if @alert.save
          render json: serialize_alert(@alert)
        else
          render json: { error: @alert.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def destroy
        @alert.destroy!
        render json: { success: true }
      end

      def toggle
        @alert.update!(active: !@alert.active)
        render json: serialize_alert(@alert)
      end

      def history
        scope = current_user.alert_histories.includes(:alert).order(triggered_at: :desc)
        scope = scope.joins(:alert).where(alerts: { symbol: params[:symbol].to_s.upcase }) if params[:symbol].present?
        limit = (params[:limit].presence || 50).to_i.clamp(1, 500)
        render json: scope.limit(limit).map { |h| serialize_history(h) }
      end

      private

      def set_alert
        @alert = current_user.alerts.find(params[:id])
      end

      def alert_params
        permitted = params.require(:alert).permit(
          :symbol, :alert_type, :cooldown_minutes, :active,
          condition: {},
          notification_channels: [],
          channels: []
        )
        permitted[:symbol] = permitted[:symbol].upcase if permitted[:symbol].present?

        # Accept either `notification_channels` (preferred) or `channels` (legacy).
        if permitted[:notification_channels].is_a?(Array)
          permitted.delete(:channels)
        elsif permitted[:channels].is_a?(Array)
          permitted[:notification_channels] = permitted.delete(:channels)
        end

        permitted
      end

      def serialize_alert(alert)
        {
          id: alert.id,
          symbol: alert.symbol,
          alert_type: alert.alert_type,
          condition: alert.condition,
          active: alert.active,
          cooldown_minutes: alert.cooldown_minutes,
          notification_channels: alert.notification_channels,
          trigger_count: alert.trigger_count,
          last_triggered_at: alert.last_triggered_at&.iso8601,
          created_at: alert.created_at.iso8601,
          human_description: alert.human_description
        }
      end

      def serialize_history(history)
        {
          id: history.id,
          alert_id: history.alert_id,
          symbol: history.symbol,
          alert_type: history.alert_type,
          message: history.message,
          triggered_at: history.triggered_at.iso8601,
          trigger_data: history.data,
          channels_notified: history.channels_notified
        }
      end

      def valid_condition?(alert)
        return false unless alert.condition.is_a?(Hash)
        value = (alert.condition["value"] || alert.condition[:value]).to_f

        case alert.alert_type
        when "price_above", "price_below", "volume_spike"
          value.positive?
        when "price_change_pct"
          direction = alert.condition["direction"] || alert.condition[:direction] || "any"
          value.positive? && %w[up down any].include?(direction.to_s)
        else
          true
        end
      end

      def condition_help(type)
        case type
        when "price_above", "price_below"
          { format: '{ "value": 200.0 }', example: "Price threshold in dollars" }
        when "price_change_pct"
          { format: '{ "value": 5.0, "direction": "up"|"down"|"any" }', example: "Percentage change threshold" }
        when "volume_spike"
          { format: '{ "value": 2.0 }', example: "Volume multiplier vs 20-day average" }
        else
          { format: '{ "value": ... }', example: "Threshold value" }
        end
      end
    end
  end
end
