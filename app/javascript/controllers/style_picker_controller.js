import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    mapId: Number
  }

  select(event) {
    const styleJson = event.currentTarget.dataset.styleJson
    const csrfToken = document.querySelector("[name='csrf-token']")?.content

    // Update visual selection
    this.element.querySelectorAll("button").forEach(btn => {
      btn.classList.remove("border-blue-600", "bg-blue-50")
    })
    event.currentTarget.classList.add("border-blue-600", "bg-blue-50")

    // Apply style to map via the map controller
    const mapEl = document.getElementById("map-canvas")
    if (mapEl && mapEl.__stimulus_map_controller) {
      mapEl.__stimulus_map_controller.applyStyle(styleJson)
    }

    // Persist to server
    fetch(`/maps/${this.mapIdValue}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken
      },
      body: JSON.stringify({ map: { style_json: styleJson } })
    })
  }
}
