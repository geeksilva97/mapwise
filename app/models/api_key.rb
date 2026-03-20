class ApiKey < ApplicationRecord
  belongs_to :user
  belongs_to :workspace

  encrypts :google_maps_key

  validates :google_maps_key, presence: true
end
