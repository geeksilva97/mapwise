class Memberships::Invite
  def self.call(workspace, email, role: "editor")
    user = ::User.find_by(email_address: email)
    return { error: "User not found" } unless user

    membership = workspace.memberships.build(user: user, role: role)
    if membership.save
      { membership: membership }
    else
      { error: membership.errors.full_messages.first }
    end
  end
end
