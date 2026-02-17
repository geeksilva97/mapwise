class EmbedsController < ApplicationController
  allow_unauthenticated_access

  layout "embed"

  def show
    @map = Maps::FindPublicByToken.call(params[:token])
    return render plain: "Map not found", status: :not_found unless @map

    @api_key = @map.embed_api_key
    render "not_configured", status: :service_unavailable unless @api_key
  end
end
