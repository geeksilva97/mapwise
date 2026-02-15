class TrackedVehicle < ApplicationRecord
  belongs_to :map
  has_many :tracking_points, dependent: :destroy
  has_many :deviation_alerts, dependent: :destroy

  validates :name, presence: true
  validates :webhook_token, presence: true, uniqueness: true
  validates :color, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }, allow_blank: true
  validates :deviation_threshold_meters, numericality: { greater_than: 0 }, allow_nil: true

  before_validation :generate_webhook_token, on: :create
  before_create :assign_position

  scope :ordered, -> { order(:position) }
  scope :active, -> { where(active: true) }

  def deviation_detection_enabled?
    planned_path.present? && deviation_threshold_meters.present?
  end

  def last_tracking_point
    tracking_points.order(recorded_at: :desc).first
  end

  private

  def generate_webhook_token
    self.webhook_token ||= SecureRandom.urlsafe_base64(16)
  end

  def assign_position
    self.position = map.tracked_vehicles.count unless position_changed?
  end
end
