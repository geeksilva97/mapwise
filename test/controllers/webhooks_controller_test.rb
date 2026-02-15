require "test_helper"

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @vehicle = tracked_vehicles(:delivery_truck)
  end

  test "should accept valid tracking data" do
    assert_difference "TrackingPoint.count", 1 do
      post webhook_tracking_path(@vehicle.webhook_token),
        params: { lat: 40.7128, lng: -74.0060, speed: 25.0, heading: 90.0 }
    end
    assert_response :ok
    data = JSON.parse(response.body)
    assert data["point_id"].present?
  end

  test "should accept minimal tracking data" do
    assert_difference "TrackingPoint.count", 1 do
      post webhook_tracking_path(@vehicle.webhook_token),
        params: { lat: 40.7128, lng: -74.0060 }
    end
    assert_response :ok
  end

  test "should accept custom recorded_at" do
    timestamp = 5.minutes.ago.iso8601
    post webhook_tracking_path(@vehicle.webhook_token),
      params: { lat: 40.7128, lng: -74.0060, recorded_at: timestamp }
    assert_response :ok
    point = TrackingPoint.find(JSON.parse(response.body)["point_id"])
    assert_in_delta Time.zone.parse(timestamp), point.recorded_at, 1.second
  end

  test "should return 404 for unknown token" do
    post webhook_tracking_path("nonexistent_token"),
      params: { lat: 40.7128, lng: -74.0060 }
    assert_response :not_found
  end

  test "should return 410 for inactive vehicle" do
    vehicle = tracked_vehicles(:inactive_van)
    post webhook_tracking_path(vehicle.webhook_token),
      params: { lat: 40.7128, lng: -74.0060 }
    assert_response :gone
  end

  test "should return 422 for invalid lat/lng" do
    post webhook_tracking_path(@vehicle.webhook_token),
      params: { lat: 999, lng: -74.0060 }
    assert_response :unprocessable_entity
  end

  test "should not require authentication" do
    # No sign_in_as call — webhook is public
    post webhook_tracking_path(@vehicle.webhook_token),
      params: { lat: 40.7128, lng: -74.0060 }
    assert_response :ok
  end

  test "should enqueue broadcast job" do
    assert_enqueued_with(job: TrackingBroadcastJob) do
      post webhook_tracking_path(@vehicle.webhook_token),
        params: { lat: 40.7128, lng: -74.0060 }
    end
  end

  test "should enqueue deviation check job when detection enabled" do
    vehicle = tracked_vehicles(:courier_bike)
    assert_enqueued_with(job: DeviationCheckJob) do
      post webhook_tracking_path(vehicle.webhook_token),
        params: { lat: 40.7128, lng: -74.0060 }
    end
  end

  test "should not enqueue deviation check job when detection disabled" do
    assert_no_enqueued_jobs(only: DeviationCheckJob) do
      post webhook_tracking_path(@vehicle.webhook_token),
        params: { lat: 40.7128, lng: -74.0060 }
    end
  end
end
