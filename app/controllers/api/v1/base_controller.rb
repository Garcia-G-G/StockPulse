# frozen_string_literal: true

module Api
  module V1
    class BaseController < ActionController::API
      include Pagy::Backend
      include ApiAuthentication

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
      rescue_from BaseClient::RateLimitExceeded, with: :rate_limited
      rescue_from BaseClient::CircuitOpenError, with: :service_unavailable
      rescue_from Faraday::TimeoutError, Faraday::ConnectionFailed, with: :gateway_timeout

      private

      def not_found
        render json: { error: "Not found" }, status: :not_found
      end

      def unprocessable_entity(exception)
        render json: { error: exception.record.errors.full_messages }, status: :unprocessable_entity
      end

      def rate_limited(exception)
        render json: { error: "Rate limit exceeded. Please try again later." }, status: :too_many_requests
      end

      def service_unavailable(exception)
        render json: { error: "External service temporarily unavailable." }, status: :service_unavailable
      end

      def gateway_timeout(exception)
        render json: { error: "External service timeout. Please try again." }, status: :gateway_timeout
      end
    end
  end
end
