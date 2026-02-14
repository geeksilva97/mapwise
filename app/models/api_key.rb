class ApiKey < ApplicationRecord
  belongs_to :user

  encrypts :google_maps_key

  validates :google_maps_key, presence: true
end
