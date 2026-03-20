class Workspace < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :maps, dependent: :destroy
  has_many :api_keys, dependent: :destroy
  has_many :map_styles, dependent: :destroy

  validates :name, presence: true
end
