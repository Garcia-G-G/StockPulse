# frozen_string_literal: true

module Api
  module V1
    class BaseController < ActionController::API
      include Pagy::Backend

      before_action :authenticate_user!

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity

      private

      def not_found
        render json: { error: "Not found" }, status: :not_found
      end

      def unprocessable_entity(exception)
        render json: { error: exception.record.errors.full_messages }, status: :unprocessable_entity
      end

      def authenticate_user!
        return if current_user

        render json: { error: "Unauthorized" }, status: :unauthorized
      end

      def current_user
        @current_user ||= User.find_by(telegram_chat_id: request.headers["X-Telegram-Chat-Id"])
      end
    end
  end
end
