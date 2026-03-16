require "test_helper"

class BrandingHelperTest < ActionView::TestCase
  test "app_name returns configured app name" do
    assert_equal Branding.app_name, app_name
  end

  test "theme_color returns configured theme color" do
    assert_equal Branding.theme_color, theme_color
  end
end
