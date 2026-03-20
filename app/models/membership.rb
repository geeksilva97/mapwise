class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :workspace

  validates :role, presence: true, inclusion: { in: %w[admin editor] }
  validates :user_id, uniqueness: { scope: :workspace_id }

  def admin?
    role == "admin"
  end

  def editor?
    role == "editor"
  end
end
