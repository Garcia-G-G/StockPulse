# frozen_string_literal: true

# API Authentication Concern
# Provides API token and Telegram chat ID based authentication
# Supports both X-API-Token (environment-based) and X-Telegram-Chat-Id (user lookup) headers
module ApiAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_api!, prepend: true
  end

  private

  # Authenticate via API token or Telegram chat ID
  def authenticate_api!
    @current_user = authenticate_via_api_token || authenticate_via_telegram_chat_id
    render_unauthorized unless @current_user
  end

  # Authenticate using X-API-Token header
  # Compares token against ENV["API_TOKEN"]
  def authenticate_via_api_token
    token = request.headers["X-API-Token"]
    return nil unless token.present?

    configured_token = ENV["API_TOKEN"]
    return nil unless configured_token.present?

    # Use secure comparison to prevent timing attacks
    return nil unless ActiveSupport::SecurityUtils.secure_compare(token, configured_token)

    # Return the first active user as the system/API user.
    # The token authenticates the request; any active user provides the context.
    # In production, consider a dedicated API user or a token-to-user mapping table.
    User.active.first
  end

  # Authenticate using X-Telegram-Chat-Id header
  # Finds user by Telegram chat ID
  def authenticate_via_telegram_chat_id
    chat_id = request.headers["X-Telegram-Chat-Id"]
    return nil unless chat_id.present?

    User.find_by(telegram_chat_id: chat_id)
  end

  # Render 401 Unauthorized response with JSON error
  def render_unauthorized
    render json: { error: "Unauthorized", message: "Missing or invalid API token" }, status: :unauthorized
  end

  # Override current_user to use authenticated user from concern
  def current_user
    @current_user
  end
end
