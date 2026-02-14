import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { mapId: Number }
  static targets = ["addButton", "placementBanner", "count"]

  // Toggle placement mode on/off
  togglePlacementMode() {
    const mapCtrl = this.#mapController()
    if (!mapCtrl) return

    if (mapCtrl.placementMode) {
      this.#exitPlacementMode(mapCtrl)
    } else {
      this.#enterPlacementMode(mapCtrl)
    }
  }

  // Called when the map controller dispatches markerPlaced
  placed(event) {
    const { lat, lng } = event.detail
    const mapCtrl = this.#mapController()
    this.#exitPlacementMode(mapCtrl)

    const csrfToken = document.querySelector("[name='csrf-token']")?.content

    fetch(`/maps/${this.mapIdValue}/markers`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": csrfToken
      },
      body: JSON.stringify({ marker: { lat, lng, title: "", color: "#FF0000" } })
    })
      .then(r => r.ok ? r.json() : null)
      .then(marker => {
        if (!marker) return

        // Update sidebar
        this.#appendMarkerToSidebar(marker)
        this.countTarget.textContent = parseInt(this.countTarget.textContent) + 1
        const empty = document.getElementById("markers_empty")
        if (empty) empty.remove()

        // Update map
        if (mapCtrl) {
          const current = mapCtrl.markersValue || []
          mapCtrl.markersValue = [...current, {
            id: marker.id, lat: marker.lat, lng: marker.lng,
            title: marker.title, description: marker.description, color: marker.color
          }]
        }
      })
  }

  // Called when a delete button is clicked on a marker item
  deleteMarker(event) {
    event.preventDefault()
    const markerId = event.params.id
    if (!confirm("Remove this marker?")) return

    const csrfToken = document.querySelector("[name='csrf-token']")?.content

    fetch(`/maps/${this.mapIdValue}/markers/${markerId}`, {
      method: "DELETE",
      headers: { "Accept": "application/json", "X-CSRF-Token": csrfToken }
    }).then(r => {
      if (!r.ok) return

      // Remove from sidebar
      const item = document.getElementById(`marker_${markerId}`)
      if (item) item.remove()
      this.countTarget.textContent = Math.max(0, parseInt(this.countTarget.textContent) - 1)

      // Remove from map
      const mapCtrl = this.#mapController()
      if (mapCtrl) {
        mapCtrl.markersValue = (mapCtrl.markersValue || []).filter(m => m.id !== markerId)
      }
    })
  }

  // Called when the map controller dispatches markerDragged
  dragged(event) {
    const { id, lat, lng } = event.detail
    const csrfToken = document.querySelector("[name='csrf-token']")?.content

    fetch(`/maps/${this.mapIdValue}/markers/${id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": csrfToken },
      body: JSON.stringify({ marker: { lat, lng } })
    })
  }

  // Capture the current map center/zoom into the settings form fields
  capturePosition() {
    const mapCtrl = this.#mapController()
    if (!mapCtrl?.map) return

    const center = mapCtrl.map.getCenter()
    const latField = document.getElementById("map_center_lat")
    const lngField = document.getElementById("map_center_lng")
    const zoomField = document.getElementById("map_zoom")

    if (latField) latField.value = Math.round(center.lat() * 1000000) / 1000000
    if (lngField) lngField.value = Math.round(center.lng() * 1000000) / 1000000
    if (zoomField) zoomField.value = mapCtrl.map.getZoom()
  }

  // --- Private ---

  #enterPlacementMode(mapCtrl) {
    mapCtrl.enterPlacementMode()
    this.addButtonTarget.textContent = "Cancel"
    this.addButtonTarget.classList.replace("bg-blue-600", "bg-gray-500")
    this.addButtonTarget.classList.replace("hover:bg-blue-500", "hover:bg-gray-400")
    this.placementBannerTarget.classList.remove("hidden")
  }

  #exitPlacementMode(mapCtrl) {
    if (mapCtrl) {
      mapCtrl.placementMode = false
      mapCtrl.element.style.cursor = ""
    }
    this.addButtonTarget.textContent = "+ Add"
    this.addButtonTarget.classList.replace("bg-gray-500", "bg-blue-600")
    this.addButtonTarget.classList.replace("hover:bg-gray-400", "hover:bg-blue-500")
    this.placementBannerTarget.classList.add("hidden")
  }

  #appendMarkerToSidebar(marker) {
    const list = document.getElementById("markers_list")
    if (!list) return

    const token = document.querySelector("[name='csrf-token']")?.content
    const item = document.createElement("div")
    item.id = `marker_${marker.id}`
    item.className = "flex items-center justify-between p-2 rounded-md hover:bg-gray-50 group"
    item.innerHTML = `
      <div class="flex items-center gap-2 min-w-0">
        <span class="w-3 h-3 rounded-full shrink-0" style="background-color: ${marker.color || "#FF0000"}"></span>
        <span class="text-sm font-medium truncate">${marker.title || "Untitled Marker"}</span>
      </div>
      <div class="flex items-center gap-2 shrink-0 opacity-0 group-hover:opacity-100">
        <a href="/maps/${this.mapIdValue}/markers/${marker.id}/edit" data-turbo-frame="marker_form" class="text-blue-600 hover:text-blue-800 text-xs font-medium">Edit</a>
        <a href="#" data-action="click->marker-editor#deleteMarker" data-marker-editor-id-param="${marker.id}" class="text-red-600 hover:text-red-800 text-xs font-medium cursor-pointer">Delete</a>
      </div>
    `
    list.appendChild(item)
  }

  #mapController() {
    const mapEl = document.getElementById("map-canvas")
    return this.application.getControllerForElementAndIdentifier(mapEl, "map")
  }
}
