class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  protected

  def after_sign_in_path_for(resource)
    if resource.onboarding_completed?
      authenticated_root_path
    else
      "/onboarding"
    end
  end

  def after_sign_up_path_for(resource)
    "/onboarding"
  end
end
