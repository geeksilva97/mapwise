class DeviationAlert < ApplicationRecord
  belongs_to :tracked_vehicle
  belongs_to :tracking_point, optional: true

  validates :distance_meters, presence: true, numericality: { greater_than: 0 }

  scope :unacknowledged, -> { where(acknowledged: false) }
  scope :recent, -> { order(created_at: :desc) }

  def acknowledge!
    update!(acknowledged: true)
  end
end
