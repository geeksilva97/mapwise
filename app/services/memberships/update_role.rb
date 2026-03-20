class Memberships::UpdateRole
  def self.call(membership, role)
    if membership.admin? && role != "admin" &&
        membership.workspace.memberships.where(role: "admin").count <= 1
      return { error: "Cannot demote the last admin" }
    end

    if membership.update(role: role)
      { membership: membership }
    else
      { error: membership.errors.full_messages.first }
    end
  end
end
