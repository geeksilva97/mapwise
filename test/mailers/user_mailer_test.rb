require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "email_verification" do
    user = users(:one)
    mail = UserMailer.email_verification(user)

    assert_equal "Verify your email address", mail.subject
    assert_equal [ user.email_address ], mail.to
    assert_equal [ Branding.mailer_from_address ], mail.from
    assert_match "Verify my email", mail.body.encoded
  end
end
