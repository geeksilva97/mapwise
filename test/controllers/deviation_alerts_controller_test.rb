require "test_helper"

class DeviationAlertsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @map = maps(:one)
    @alert = deviation_alerts(:bike_deviation)
  end

  test "should acknowledge alert" do
    patch acknowledge_map_deviation_alert_path(@map, @alert), as: :json
    assert_response :success
    assert @alert.reload.acknowledged?
  end

  test "should not acknowledge alert on other user map" do
    sign_out
    sign_in_as users(:two)
    patch acknowledge_map_deviation_alert_path(@map, @alert), as: :json
    assert_response :not_found
  end

  test "should return 404 for non-existent alert" do
    patch acknowledge_map_deviation_alert_path(@map, -1), as: :json
    assert_response :not_found
  end

  test "acknowledging already-acknowledged alert is idempotent" do
    acknowledged = deviation_alerts(:old_alert)
    assert acknowledged.acknowledged?
    patch acknowledge_map_deviation_alert_path(@map, acknowledged), as: :json
    assert_response :success
    assert acknowledged.reload.acknowledged?
  end

  test "should acknowledge alert via turbo_stream" do
    alert = deviation_alerts(:bike_deviation)
    patch acknowledge_map_deviation_alert_path(@map, alert), as: :turbo_stream
    assert_response :success
    assert alert.reload.acknowledged?
  end

  test "should require authentication" do
    sign_out
    patch acknowledge_map_deviation_alert_path(@map, @alert), as: :json
    assert_response :redirect
  end
end
