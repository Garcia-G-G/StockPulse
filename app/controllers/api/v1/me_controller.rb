# frozen_string_literal: true

module Api
  module V1
    class MeController < BaseController
      def show
        render json: {
          user: {
            id: current_user.id,
            name: current_user.name,
            email: current_user.email,
            onboarding_completed: current_user.onboarding_completed
          }
        }
      end
    end
  end
end
