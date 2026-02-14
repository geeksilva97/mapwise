import { Controller } from "@hotwired/stimulus"
import { csrfToken } from "utils/csrf"

export default class extends Controller {
  static values = {
    mapId: Number
  }

  select(event) {
    const styleJson = event.currentTarget.value

    // Apply style to map via the map controller
    const mapEl = document.getElementById("map-canvas")
    const mapController = this.application.getControllerForElementAndIdentifier(mapEl, "map")
    if (mapController) {
      mapController.applyStyle(styleJson)
    }

    // Persist to server
    fetch(`/maps/${this.mapIdValue}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken()
      },
      body: JSON.stringify({ map: { style_json: styleJson } })
    })
      .catch(err => console.error("Failed to save style:", err))
  }
}
