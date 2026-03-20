class MapStyle < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :workspace, optional: true

  validates :name, presence: true
  validates :style_json, presence: true

  scope :system_presets, -> { where(system_default: true) }
  scope :for_user, ->(user) { where(user: user).or(where(system_default: true)) }
  scope :for_workspace, ->(workspace) { where(workspace: workspace).or(where(system_default: true)) }
end
