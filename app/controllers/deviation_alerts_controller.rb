class DeviationAlertsController < ApplicationController
  before_action :set_map

  def acknowledge
    alert = Tracking::AcknowledgeAlert.call(@map, params[:id])

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("alert_#{alert.id}") }
      format.json { render json: alert }
    end
  end

  private

  def set_map
    @map = Maps::Find.call(Current.user, params[:map_id])
  end
end
