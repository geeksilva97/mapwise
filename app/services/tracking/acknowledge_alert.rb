class Tracking::AcknowledgeAlert
  def self.call(map, alert_id)
    alert = map.tracked_vehicles
      .joins(:deviation_alerts)
      .find_by!(deviation_alerts: { id: alert_id })
      .deviation_alerts
      .find(alert_id)

    alert.acknowledge!
    alert
  end
end
