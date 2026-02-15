require "test_helper"
require "webmock/minitest"

class GeocodeServiceTest < ActiveSupport::TestCase
  setup do
    WebMock.disable_net_connect!
  end

  teardown do
    WebMock.allow_net_connect!
  end

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

  test "returns coordinates on successful geocode" do
    body = {
      status: "OK",
      results: [ { geometry: { location: { lat: 40.7128, lng: -74.006 } } } ]
    }.to_json

    stub_request(:get, /maps.googleapis.com\/maps\/api\/geocode/)
      .to_return(status: 200, body: body, headers: { "Content-Type" => "application/json" })

    result = GeocodeService.geocode("New York, NY", "test_key")
    assert result[:success]
    assert_in_delta 40.7128, result[:lat], 0.001
    assert_in_delta(-74.006, result[:lng], 0.001)
  end

  test "returns error when API returns ZERO_RESULTS" do
    body = { status: "ZERO_RESULTS", results: [] }.to_json

    stub_request(:get, /maps.googleapis.com\/maps\/api\/geocode/)
      .to_return(status: 200, body: body, headers: { "Content-Type" => "application/json" })

    result = GeocodeService.geocode("zzzznotaplace", "test_key")
    assert_not result[:success]
    assert_match(/ZERO_RESULTS/, result[:error])
  end

  test "returns error on HTTP failure" do
    stub_request(:get, /maps.googleapis.com\/maps\/api\/geocode/)
      .to_return(status: 500, body: "Internal Server Error")

    result = GeocodeService.geocode("123 Main St", "test_key")
    assert_not result[:success]
    assert_match(/HTTP error: 500/, result[:error])
  end

  test "returns error on network exception" do
    stub_request(:get, /maps.googleapis.com\/maps\/api\/geocode/)
      .to_raise(SocketError.new("getaddrinfo: Name or service not known"))

    result = GeocodeService.geocode("123 Main St", "test_key")
    assert_not result[:success]
    assert_match(/Name or service not known/, result[:error])
  end
end
