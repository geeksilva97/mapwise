class MarkerGroup < ApplicationRecord
  belongs_to :map
  has_many :markers, dependent: :nullify

  validates :name, presence: true
  validates :color, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }, allow_blank: true

  before_create :assign_position

  scope :ordered, -> { order(:position) }
  scope :visible, -> { where(visible: true) }

  private

  def assign_position
    self.position = map.marker_groups.count unless position_changed?
  end
end
