class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :check_email_verification_deadline

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def platform_api_key
    Rails.application.credentials.google_maps_api_key
  end
  helper_method :platform_api_key

  def check_email_verification_deadline
    return unless Current.user&.email_verification_expired?

    render "email_verifications/expired", status: :forbidden
  end
end
