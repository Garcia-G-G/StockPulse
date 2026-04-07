# frozen_string_literal: true

class OnboardingController < ApplicationController
  layout "landing"
  before_action :authenticate_user!

  def show
    redirect_to authenticated_root_path if current_user.onboarding_completed?
  end

  def update
    step = params[:step].to_i
    case step
    when 1
      render json: { success: true, next_step: 2 }
    when 2
      symbols = params.dig(:data, :symbols) || []
      symbols.first(20).each do |s|
        next unless s.match?(/\A[A-Z]{1,5}\z/)
        current_user.watchlist_items.find_or_create_by(symbol: s.upcase) do |wi|
          wi.added_at = Time.current
        end
      end
      render json: { success: true, next_step: 3 }
    when 3
      symbol = params.dig(:data, :symbol)
      raw_condition = params.dig(:data, :condition)
      if symbol.present? && raw_condition.is_a?(ActionController::Parameters)
        direction = raw_condition[:direction]
        price = raw_condition[:price].to_f
        if %w[above below].include?(direction) && price > 0
          alert_type = direction == "above" ? "price_above" : "price_below"
          current_user.alerts.create(
            symbol: symbol.upcase,
            alert_type: alert_type,
            condition: { direction: direction, price: price },
            channels: { email: true }
          )
        end
      end
      render json: { success: true, next_step: 4 }
    when 4
      updates = {}
      telegram = params.dig(:data, :telegram_chat_id)
      whatsapp = params.dig(:data, :whatsapp_number)
      updates[:telegram_chat_id] = telegram if telegram.present?
      updates[:whatsapp_number] = whatsapp if whatsapp.present?
      if updates.any?
        unless current_user.update(updates)
          render json: { success: false, errors: current_user.errors.full_messages }, status: :unprocessable_entity
          return
        end
      end
      render json: { success: true, next_step: 5 }
    when 5
      current_user.update!(onboarding_completed: true)
      render json: { success: true, redirect_to: authenticated_root_path }
    else
      render json: { error: "Invalid step" }, status: :unprocessable_entity
    end
  end
end
