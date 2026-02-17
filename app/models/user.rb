class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :api_keys, dependent: :destroy
  has_many :maps, dependent: :destroy
  has_many :map_styles, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :password, length: { minimum: 8 }, allow_nil: true

  generates_token_for :email_verification, expires_in: 3.days

  def verify_email!
    update!(email_verified: true, email_verified_at: Time.current)
  end

  def email_verification_deadline
    created_at + 7.days
  end

  def email_verification_expired?
    !email_verified? && Time.current > email_verification_deadline
  end
end
