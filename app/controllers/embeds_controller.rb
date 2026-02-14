class EmbedsController < ApplicationController
  allow_unauthenticated_access

  layout "embed"

  def show
    @map = Map.find_by(embed_token: params[:token])

    if @map.nil?
      render plain: "Map not found", status: :not_found
      return
    end

    unless @map.public?
      render plain: "Map not found", status: :not_found
      return
    end

    @api_key = @map.user.api_keys.first&.google_maps_key

    unless @api_key
      render "not_configured", status: :service_unavailable
    end
  end
end
