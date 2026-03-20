class WorkspacesController < ApplicationController
  before_action :set_workspace, only: %i[ show edit update destroy switch ]
  before_action :authorize_workspace_admin!, only: %i[ edit update destroy ]

  def new
    @workspace = Workspace.new
  end

  def create
    @workspace = Workspaces::Create.call(Current.user, workspace_params)

    if @workspace.persisted?
      session[:current_workspace_id] = @workspace.id
      redirect_to workspace_path(@workspace), notice: "Workspace created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @memberships = Memberships::List.call(@workspace)
    @membership = @workspace.memberships.find_by(user: Current.user)
  end

  def edit
  end

  def update
    if Workspaces::Update.call(@workspace, workspace_params)
      redirect_to workspace_path(@workspace), notice: "Workspace updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @workspace.personal?
      redirect_to workspace_path(@workspace), alert: "Cannot delete your personal workspace."
      return
    end

    Workspaces::Destroy.call(@workspace)
    session.delete(:current_workspace_id)
    redirect_to root_path, notice: "Workspace deleted.", status: :see_other
  end

  def switch
    session[:current_workspace_id] = @workspace.id
    redirect_to root_path, notice: "Switched to #{@workspace.name}."
  end

  private

  def set_workspace
    @workspace = Current.user.workspaces.find(params[:id])
  end

  def authorize_workspace_admin!
    membership = @workspace.memberships.find_by(user: Current.user)
    unless membership&.admin?
      redirect_to workspace_path(@workspace), alert: "You are not authorized to perform this action."
    end
  end

  def workspace_params
    params.require(:workspace).permit(:name)
  end
end
