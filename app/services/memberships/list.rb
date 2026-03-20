class Memberships::List
  def self.call(workspace)
    workspace.memberships.includes(:user).order(:created_at)
  end
end
