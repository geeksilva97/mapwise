class Layer < ApplicationRecord
  LAYER_TYPES = %w[polygon line circle rectangle freehand].freeze

  belongs_to :map

  validates :name, presence: true
  validates :layer_type, presence: true, inclusion: { in: LAYER_TYPES }
  validates :geometry_data, presence: true
  validates :stroke_color, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }, allow_blank: true
  validates :fill_color, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }, allow_blank: true
  validates :stroke_width, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 20 }, allow_nil: true
  validates :fill_opacity, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true

  before_create :assign_position

  scope :ordered, -> { order(:position) }
  scope :visible, -> { where(visible: true) }

  def geojson
    JSON.parse(geometry_data)
  rescue JSON::ParserError
    {}
  end

  private

  def assign_position
    self.position = map.layers.count unless position_changed?
  end
end
