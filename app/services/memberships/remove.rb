class Memberships::Remove
  def self.call(membership)
    if membership.admin? && membership.workspace.memberships.where(role: "admin").count <= 1
      return { error: "Cannot remove the last admin" }
    end

    membership.destroy
    { membership: membership }
  end
end
