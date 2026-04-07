# frozen_string_literal: true

class LandingController < ApplicationController
  layout "landing"

  def index
    redirect_to authenticated_root_path if user_signed_in?
  end
end
