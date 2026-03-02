class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :redirect_to_onboarding

  private

  def redirect_to_onboarding
    return unless user_signed_in?
    return if current_user.team.present?
    return if controller_name == "onboarding"
    return if devise_controller?

    redirect_to new_onboarding_path
  end
end
