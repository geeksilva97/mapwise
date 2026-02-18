import { Controller } from "@hotwired/stimulus"
import { fireAndForget } from "utils/http"

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
    fireAndForget(`/maps/${this.mapIdValue}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ map: { style_json: styleJson } })
    })
  }
}
