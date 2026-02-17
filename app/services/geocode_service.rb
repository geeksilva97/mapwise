require "net/http"
require "json"

class GeocodeService
  GEOCODING_URL = "https://maps.googleapis.com/maps/api/geocode/json".freeze

  def self.geocode(address, api_key)
    return { success: false, error: "No address provided" } if address.blank?
    return { success: false, error: "No API key provided" } if api_key.blank?

    uri = URI(GEOCODING_URL)
    uri.query = URI.encode_www_form(address: address, key: api_key)

    response = Net::HTTP.get_response(uri)

    unless response.is_a?(Net::HTTPSuccess)
      return { success: false, error: "HTTP error: #{response.code}" }
    end

    data = JSON.parse(response.body)

    if data["status"] == "OK" && data["results"].any?
      location = data["results"].first["geometry"]["location"]
      { success: true, lat: location["lat"], lng: location["lng"] }
    else
      { success: false, error: "Geocoding failed: #{data['status']}" }
    end
  rescue StandardError => e
    Rails.error.report(e, handled: true, context: { address: address }, source: "geocode_service")
    { success: false, error: e.message }
  end
end
