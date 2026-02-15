class DeviationAlertsController < ApplicationController
  before_action :set_map

  def acknowledge
    alert = @map.tracked_vehicles
      .joins(:deviation_alerts)
      .find_by!(deviation_alerts: { id: params[:id] })
      .deviation_alerts
      .find(params[:id])

    alert.acknowledge!

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("alert_#{alert.id}") }
      format.json { render json: alert }
    end
  end

  private

  def set_map
    @map = Current.user.maps.find(params[:map_id])
  end
end
