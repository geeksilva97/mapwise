class Map < ApplicationRecord
  belongs_to :user
  has_many :markers, dependent: :destroy

  before_create :generate_embed_token

  validates :title, presence: true
  validates :embed_token, uniqueness: true, allow_nil: true

  private

  def generate_embed_token
    self.embed_token = SecureRandom.urlsafe_base64(16)
  end
end
