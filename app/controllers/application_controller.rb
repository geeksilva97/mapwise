class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :check_email_verification_deadline
  before_action :set_current_workspace

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def platform_api_key
    Rails.application.credentials.google_maps_api_key
  end
  helper_method :platform_api_key

  def current_workspace
    Current.workspace
  end
  helper_method :current_workspace

  def set_current_workspace
    return unless Current.user

    if session[:current_workspace_id]
      Current.workspace = Current.user.workspaces.find_by(id: session[:current_workspace_id])
    end

    Current.workspace ||= Current.user.personal_workspace
    session[:current_workspace_id] = Current.workspace&.id
  end

  def authorize_admin!
    membership = Current.workspace&.memberships&.find_by(user: Current.user)
    unless membership&.admin?
      respond_to do |format|
        format.html { redirect_to root_path, alert: "You are not authorized to perform this action." }
        format.json { render json: { error: "Forbidden" }, status: :forbidden }
        format.turbo_stream { head :forbidden }
      end
    end
  end

  def check_email_verification_deadline
    return unless Current.user&.email_verification_expired?

    render "email_verifications/expired", status: :forbidden
  end
end
