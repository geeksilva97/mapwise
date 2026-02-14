class GeocodeJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(marker_id, api_key)
    marker = Marker.find(marker_id)
    return if marker.lat != 0.0 || marker.lng != 0.0

    address = [ marker.title, marker.description ].compact.join(", ")
    result = GeocodeService.geocode(address, api_key)

    if result[:success]
      marker.update!(lat: result[:lat], lng: result[:lng])
    else
      Rails.logger.warn "Geocoding failed for marker #{marker_id}: #{result[:error]}"
    end
  end
end
