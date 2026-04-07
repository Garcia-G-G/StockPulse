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
      condition = params.dig(:data, :condition)
      if symbol.present? && condition.present?
        current_user.alerts.create(
          symbol: symbol.upcase,
          alert_type: "price_above",
          condition: condition,
          channels: { email: true }
        )
      end
      render json: { success: true, next_step: 4 }
    when 4
      updates = {}
      telegram = params.dig(:data, :telegram_chat_id)
      whatsapp = params.dig(:data, :whatsapp_number)
      updates[:telegram_chat_id] = telegram if telegram.present?
      updates[:whatsapp_number] = whatsapp if whatsapp.present?
      current_user.update(updates) if updates.any?
      render json: { success: true, next_step: 5 }
    when 5
      current_user.update!(onboarding_completed: true)
      render json: { success: true, redirect_to: authenticated_root_path }
    else
      render json: { error: "Invalid step" }, status: :unprocessable_entity
    end
  end
end
