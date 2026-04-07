# frozen_string_literal: true

module ApiAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user_or_api!, prepend: true
  end

  private

  def authenticate_user_or_api!
    return if user_signed_in?
    return if authenticate_via_api_token!
    return if authenticate_via_telegram_chat_id!
    render_unauthorized
  end

  def authenticate_via_api_token!
    token = request.headers["X-API-Token"]
    return false unless token.present?

    configured_token = ENV["API_TOKEN"]
    return false unless configured_token.present?
    return false unless ActiveSupport::SecurityUtils.secure_compare(token, configured_token)

    @current_user = User.active.first
    true
  end

  def authenticate_via_telegram_chat_id!
    chat_id = request.headers["X-Telegram-Chat-Id"]
    return false unless chat_id.present?

    @current_user = User.find_by(telegram_chat_id: chat_id, active: true)
    @current_user.present?
  end

  def render_unauthorized
    render json: { error: "Unauthorized", message: "Missing or invalid credentials" }, status: :unauthorized
  end

  def current_user
    @current_user || super
  end
end
