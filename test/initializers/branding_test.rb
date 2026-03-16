require "test_helper"

class BrandingTest < ActiveSupport::TestCase
  test "app_name defaults to MapWise" do
    assert_equal "MapWise", Rails.application.config.app_name
  end

  test "app_name is accessible via Branding module" do
    assert_equal Rails.application.config.app_name, Branding.app_name
  end

  test "mailer_from uses app_name and mailer_from_address" do
    expected = "#{Branding.app_name} <#{Branding.mailer_from_address}>"
    assert_equal expected, Branding.mailer_from
  end

  test "mailer_from_address defaults to noreply@example.com" do
    assert_match(/@/, Branding.mailer_from_address)
  end

  test "theme_color has a default" do
    assert Branding.theme_color.present?
  end
end
