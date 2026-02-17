module EmailVerifications
  class Verify
    def self.call(token)
      user = ::User.find_by_token_for(:email_verification, token)
      return nil unless user

      user.verify_email!
      user
    end
  end
end
