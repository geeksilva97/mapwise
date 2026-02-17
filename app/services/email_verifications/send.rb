module EmailVerifications
  class Send
    def self.call(user)
      UserMailer.email_verification(user).deliver_later
    end
  end
end
