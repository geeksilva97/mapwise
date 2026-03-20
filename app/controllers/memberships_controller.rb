class MembershipsController < ApplicationController
  before_action :set_workspace
  before_action :authorize_workspace_admin!

  def create
    role = validated_role
    result = Memberships::Invite.call(@workspace, params[:email], role: role)

    if result[:error]
      redirect_to workspace_path(@workspace), alert: result[:error]
    else
      redirect_to workspace_path(@workspace), notice: "Member invited."
    end
  end

  def update
    membership = @workspace.memberships.find(params[:id])
    role = validated_role
    result = Memberships::UpdateRole.call(membership, role)

    if result[:error]
      redirect_to workspace_path(@workspace), alert: result[:error]
    else
      redirect_to workspace_path(@workspace), notice: "Role updated."
    end
  end

  def destroy
    membership = @workspace.memberships.find(params[:id])
    result = Memberships::Remove.call(membership)

    if result[:error]
      redirect_to workspace_path(@workspace), alert: result[:error]
    else
      redirect_to workspace_path(@workspace), notice: "Member removed."
    end
  end

  private

  def set_workspace
    @workspace = Current.user.workspaces.find(params[:workspace_id])
  end

  def validated_role
    params[:role].presence_in(%w[admin editor]) || "editor"
  end

  def authorize_workspace_admin!
    membership = @workspace.memberships.find_by(user: Current.user)
    unless membership&.admin?
      redirect_to workspace_path(@workspace), alert: "You are not authorized to perform this action."
    end
  end
end
