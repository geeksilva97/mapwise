class Memberships::UpdateRole
  def self.call(membership, role)
    membership.update(role: role)
  end
end
