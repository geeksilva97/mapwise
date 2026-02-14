class Marker < ApplicationRecord
  belongs_to :map, counter_cache: true

  validates :lat, presence: true, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :lng, presence: true, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
  validates :color, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }, allow_blank: true

  before_create :assign_position

  private

  def assign_position
    self.position = map.markers.count unless position_changed?
  end
end
