require "test_helper"

class DeviationAlertTest < ActiveSupport::TestCase
  setup do
    @alert = deviation_alerts(:bike_deviation)
  end

  test "valid alert" do
    assert @alert.valid?
  end

  test "requires distance_meters" do
    @alert.distance_meters = nil
    assert_not @alert.valid?
  end

  test "distance_meters must be positive" do
    @alert.distance_meters = 0
    assert_not @alert.valid?

    @alert.distance_meters = -10
    assert_not @alert.valid?
  end

  test "tracking_point is optional" do
    alert = deviation_alerts(:old_alert)
    assert_nil alert.tracking_point
    assert alert.valid?
  end

  test "unacknowledged scope" do
    unacked = DeviationAlert.unacknowledged
    assert_includes unacked, deviation_alerts(:bike_deviation)
    assert_not_includes unacked, deviation_alerts(:old_alert)
  end

  test "recent scope orders by created_at desc" do
    alerts = DeviationAlert.recent
    assert_equal alerts.first.created_at, alerts.map(&:created_at).max
  end

  test "acknowledge!" do
    assert_not @alert.acknowledged?
    @alert.acknowledge!
    assert @alert.reload.acknowledged?
  end

  test "acknowledge! is idempotent" do
    alert = deviation_alerts(:old_alert)
    assert alert.acknowledged?
    assert_nothing_raised { alert.acknowledge! }
    assert alert.reload.acknowledged?
  end

  test "deleting tracking point nullifies alert reference" do
    alert = deviation_alerts(:bike_deviation)
    assert_not_nil alert.tracking_point
    alert.tracking_point.destroy!
    assert_nil alert.reload.tracking_point_id
    assert alert.valid?
  end
end
