# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  layout "landing"

  protected

  def sign_up_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
