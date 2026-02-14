require "test_helper"

class GeocodeServiceTest < ActiveSupport::TestCase
  test "returns error for blank address" do
    result = GeocodeService.geocode("", "fake_key")
    assert_not result[:success]
    assert_equal "No address provided", result[:error]
  end

  test "returns error for blank api_key" do
    result = GeocodeService.geocode("123 Main St", "")
    assert_not result[:success]
    assert_equal "No API key provided", result[:error]
  end

  test "returns error for nil address" do
    result = GeocodeService.geocode(nil, "fake_key")
    assert_not result[:success]
    assert_equal "No address provided", result[:error]
  end

  test "returns error for nil api_key" do
    result = GeocodeService.geocode("123 Main St", nil)
    assert_not result[:success]
    assert_equal "No API key provided", result[:error]
  end
end
