require "test_helper"
require "webmock/minitest"

class GeocodeJobTest < ActiveJob::TestCase
  setup do
    WebMock.disable_net_connect!
  end

  teardown do
    WebMock.allow_net_connect!
  end

  test "updates marker with geocoded coordinates" do
    marker = markers(:one)
    marker.update_columns(lat: 0.0, lng: 0.0)

    body = {
      status: "OK",
      results: [ { geometry: { location: { lat: 40.7128, lng: -74.006 } } } ]
    }.to_json

    stub_request(:get, /maps.googleapis.com\/maps\/api\/geocode/)
      .to_return(status: 200, body: body, headers: { "Content-Type" => "application/json" })

    GeocodeJob.perform_now(marker.id, "fake_key")

    marker.reload
    assert_in_delta 40.7128, marker.lat, 0.001
    assert_in_delta(-74.006, marker.lng, 0.001)
  end

  test "skips marker that already has coordinates" do
    marker = markers(:one)
    original_lat = marker.lat
    original_lng = marker.lng

    # No stub needed — it should not call the API
    GeocodeJob.perform_now(marker.id, "fake_key")

    marker.reload
    assert_equal original_lat, marker.lat
    assert_equal original_lng, marker.lng
  end

  test "does not update marker when geocoding fails" do
    marker = markers(:one)
    marker.update_columns(lat: 0.0, lng: 0.0)

    body = { status: "ZERO_RESULTS", results: [] }.to_json

    stub_request(:get, /maps.googleapis.com\/maps\/api\/geocode/)
      .to_return(status: 200, body: body, headers: { "Content-Type" => "application/json" })

    GeocodeJob.perform_now(marker.id, "fake_key")

    marker.reload
    assert_in_delta 0.0, marker.lat, 0.001
    assert_in_delta 0.0, marker.lng, 0.001
  end

  test "handles missing marker gracefully" do
    assert_nothing_raised do
      GeocodeJob.perform_now(-1, "fake_key")
    end
  end
end
