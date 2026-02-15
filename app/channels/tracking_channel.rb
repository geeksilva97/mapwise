class TrackingChannel < ApplicationCable::Channel
  def subscribed
    map = current_user.maps.find_by(id: params[:map_id])

    if map
      stream_from "tracking_map_#{map.id}"
    else
      reject
    end
  end
end
