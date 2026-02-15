class ChatMessage < ApplicationRecord
  belongs_to :map

  validates :role, presence: true, inclusion: { in: %w[user assistant] }
  validates :content, presence: true

  scope :ordered, -> { order(:created_at) }
end
