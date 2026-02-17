class UserMailer < ApplicationMailer
  def email_verification(user)
    @user = user
    mail subject: "Verify your email address", to: user.email_address
  end
end
