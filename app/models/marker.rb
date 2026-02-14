class Marker < ApplicationRecord
  belongs_to :map, counter_cache: true
  belongs_to :marker_group, optional: true

  validates :lat, presence: true, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :lng, presence: true, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
  validates :color, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }, allow_blank: true

  before_create :assign_position
  before_save :sanitize_custom_info_html

  private

  def assign_position
    self.position = map.markers.count unless position_changed?
  end

  def sanitize_custom_info_html
    return if custom_info_html.blank?

    sanitizer = Rails::HTML5::SafeListSanitizer.new
    self.custom_info_html = sanitizer.sanitize(
      custom_info_html,
      tags: %w[p br strong em a img ul ol li h3 h4 h5 h6 span div],
      attributes: %w[href src alt class style target]
    )
  end
end
