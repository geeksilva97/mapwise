class Map < ApplicationRecord
  belongs_to :user
  has_many :markers, dependent: :destroy

  attribute :center_lat, :float, default: 39.8283
  attribute :center_lng, :float, default: -98.5795
  attribute :zoom, :integer, default: 4

  before_create :generate_embed_token

  validates :title, presence: true
  validates :embed_token, uniqueness: true, allow_nil: true

  def self.find_public_by_token(token)
    find_by(embed_token: token, public: true)
  end

  def embed_api_key
    user.api_keys.first&.google_maps_key
  end

  private

  def generate_embed_token
    self.embed_token = SecureRandom.urlsafe_base64(16)
  end
end
