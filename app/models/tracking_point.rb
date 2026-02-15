class TrackingPoint < ApplicationRecord
  belongs_to :tracked_vehicle
  has_one :deviation_alert, dependent: :nullify

  validates :lat, presence: true, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :lng, presence: true, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
  validates :recorded_at, presence: true
  validates :speed, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :heading, numericality: { greater_than_or_equal_to: 0, less_than: 360 }, allow_nil: true

  scope :chronological, -> { order(:recorded_at) }
  scope :in_range, ->(from, to) { where(recorded_at: from..to) }
end
