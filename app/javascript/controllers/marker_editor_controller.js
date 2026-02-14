import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    mapId: Number
  }

  // Proxy to the map controller's enterPlacementMode (button is in sidebar, map controller is on #map-canvas)
  enterPlacementMode() {
    const mapEl = document.getElementById("map-canvas")
    const mapController = this.application.getControllerForElementAndIdentifier(mapEl, "map")
    if (mapController) mapController.enterPlacementMode()
  }

  // Called when the map controller dispatches markerPlaced
  placed(event) {
    const { lat, lng } = event.detail
    const csrfToken = document.querySelector("[name='csrf-token']")?.content

    fetch(`/maps/${this.mapIdValue}/markers`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "text/vnd.turbo-stream.html",
        "X-CSRF-Token": csrfToken
      },
      body: JSON.stringify({
        marker: { lat, lng, title: "", color: "#FF0000" }
      })
    }).then(response => {
      if (response.ok) {
        return response.text()
      }
    }).then(html => {
      if (html) {
        Turbo.renderStreamMessage(html)
        this.refreshMapMarkers()
      }
    })
  }

  // Called when the map controller dispatches markerDragged
  dragged(event) {
    const { id, lat, lng } = event.detail
    const csrfToken = document.querySelector("[name='csrf-token']")?.content

    fetch(`/maps/${this.mapIdValue}/markers/${id}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "Accept": "text/vnd.turbo-stream.html",
        "X-CSRF-Token": csrfToken
      },
      body: JSON.stringify({
        marker: { lat, lng }
      })
    })
  }

  // Re-read markers data from the JSON script tag and update the map controller
  refreshMapMarkers() {
    const dataEl = document.getElementById("markers-data")
    if (dataEl) {
      try {
        const markers = JSON.parse(dataEl.textContent)
        const mapEl = document.getElementById("map-canvas")
        if (mapEl) {
          mapEl.setAttribute("data-map-markers-value", JSON.stringify(markers))
        }
      } catch (e) {
        // ignore parse errors
      }
    }
  }
}
