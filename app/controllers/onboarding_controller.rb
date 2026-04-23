# frozen_string_literal: true

class OnboardingController < ApplicationController
  layout "landing"
  before_action :authenticate_user!

  TOTAL_STEPS = 4

  def show
    redirect_to authenticated_root_path if current_user.onboarding_completed?
  end

  def update
    step = params[:step].to_i
    case step
    when 1
      render json: { success: true, next_step: 2 }
    when 2
      create_onboarding_alert(
        symbol: params.dig(:data, :symbol),
        alert_type: params.dig(:data, :alert_type),
        raw_condition: params.dig(:data, :condition)
      )
      render json: { success: true, next_step: 3 }
    when 3
      updates = {}
      email = params.dig(:data, :email)
      telegram = params.dig(:data, :telegram_chat_id)
      whatsapp = params.dig(:data, :whatsapp_number)
      updates[:email] = email if email.present? && email != current_user.email
      updates[:telegram_chat_id] = telegram if telegram.present?
      updates[:whatsapp_number] = whatsapp if whatsapp.present?
      if updates.any?
        unless current_user.update(updates)
          render json: { success: false, errors: current_user.errors.full_messages }, status: :unprocessable_entity
          return
        end
      end
      render json: { success: true, next_step: 4 }
    when 4
      current_user.update!(onboarding_completed: true)
      render json: { success: true, redirect_to: authenticated_root_path }
    else
      render json: { error: "Invalid step" }, status: :unprocessable_entity
    end
  end

  private

  def create_onboarding_alert(symbol:, alert_type:, raw_condition:)
    return if symbol.blank? || !raw_condition.is_a?(ActionController::Parameters)

    case alert_type.to_s
    when "price_change_pct"
      value = raw_condition[:value].to_f
      direction = raw_condition[:direction].to_s
      return unless value.positive? && %w[up down any].include?(direction)

      current_user.alerts.create(
        symbol: symbol.upcase,
        alert_type: "price_change_pct",
        condition: { "value" => value, "direction" => direction },
        channels: ["email"]
      )
    else
      direction = raw_condition[:direction].to_s
      price = raw_condition[:price].to_f
      return unless %w[above below].include?(direction) && price.positive?

      current_user.alerts.create(
        symbol: symbol.upcase,
        alert_type: direction == "above" ? "price_above" : "price_below",
        condition: { "value" => price },
        channels: ["email"]
      )
    end
  end
end
