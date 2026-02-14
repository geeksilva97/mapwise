class Marker < ApplicationRecord
  belongs_to :map

  validates :lat, presence: true
  validates :lng, presence: true
end
