import { Controller } from "@hotwired/stimulus"
import { csrfToken } from "utils/csrf"

export default class extends Controller {
  static values = { mapId: Number }
  static targets = ["addButton", "placementBanner", "circleSelectionBanner", "count"]

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

    fetch(`/maps/${this.mapIdValue}/markers`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": csrfToken()
      },
      body: JSON.stringify({ marker: { lat, lng, title: "", color: "#FF0000" } })
    })
      .then(r => {
        if (!r.ok) throw new Error(`Failed to create marker: ${r.status}`)
        return r.json()
      })
      .then(marker => {
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
      .catch(err => this.#showError("Failed to create marker.", err))
  }

  // Show inline delete confirmation for a marker
  deleteMarker(event) {
    event.preventDefault()
    const markerId = event.params.id
    const item = document.getElementById(`marker_${markerId}`)
    if (!item) return

    item.querySelector('[data-role="content"]').classList.add("hidden")
    item.querySelector('[data-role="confirm"]').classList.remove("hidden")
  }

  // Cancel inline delete confirmation
  cancelDelete(event) {
    event.preventDefault()
    const item = event.target.closest('[id^="marker_"]')
    if (!item) return

    item.querySelector('[data-role="content"]').classList.remove("hidden")
    item.querySelector('[data-role="confirm"]').classList.add("hidden")
  }

  // Confirm and execute marker deletion
  confirmDeleteMarker(event) {
    event.preventDefault()
    const markerId = event.params.id

    fetch(`/maps/${this.mapIdValue}/markers/${markerId}`, {
      method: "DELETE",
      headers: { "Accept": "application/json", "X-CSRF-Token": csrfToken() }
    })
      .then(r => {
        if (!r.ok) throw new Error(`Failed to delete marker: ${r.status}`)

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
      .catch(err => this.#showError("Failed to delete marker.", err))
  }

  // Remove a marker from its group
  ungroupMarker(event) {
    event.preventDefault()
    const markerId = event.params.id

    fetch(`/maps/${this.mapIdValue}/markers/${markerId}/ungroup`, {
      method: "PATCH",
      headers: { "Accept": "application/json", "X-CSRF-Token": csrfToken() }
    })
      .then(r => {
        if (!r.ok) throw new Error(`Failed to ungroup marker: ${r.status}`)
        return r.json()
      })
      .then(() => {
        window.location.reload()
      })
      .catch(err => this.#showError("Failed to ungroup marker.", err))
  }

  // Called when the map controller dispatches markerDragged
  dragged(event) {
    const { id, lat, lng } = event.detail

    fetch(`/maps/${this.mapIdValue}/markers/${id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": csrfToken() },
      body: JSON.stringify({ marker: { lat, lng } })
    })
      .catch(err => this.#showError("Failed to save marker position.", err))
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

  // Proxy layer actions to drawing controller (sidebar can't reach it directly)
  deleteLayer(event) {
    const drawingCtrl = this.#drawingController()
    if (drawingCtrl) drawingCtrl.deleteLayer(event)
  }

  toggleLayerVisibility(event) {
    const drawingCtrl = this.#drawingController()
    if (drawingCtrl) drawingCtrl.toggleLayerVisibility(event)
  }

  showCircleBanner() {
    if (this.hasCircleSelectionBannerTarget) {
      this.circleSelectionBannerTarget.classList.remove("hidden")
    }
  }

  hideCircleBanner() {
    if (this.hasCircleSelectionBannerTarget) {
      this.circleSelectionBannerTarget.classList.add("hidden")
    }
  }

  // Pan the map to a marker on double-click
  focusMarker(event) {
    const markerId = Number(event.currentTarget.dataset.markerId)
    const mapCtrl = this.#mapController()
    if (!mapCtrl) return

    const marker = (mapCtrl.markersValue || []).find(m => m.id === markerId)
    if (marker) mapCtrl.panTo(marker.lat, marker.lng, undefined, { persist: false })
  }

  // Pan the map to a layer's center on double-click
  focusLayer(event) {
    const layerId = Number(event.currentTarget.dataset.layerId)
    const drawingCtrl = this.#drawingController()
    if (!drawingCtrl) return

    const layer = (drawingCtrl.layersValue || []).find(l => l.id === layerId)
    if (!layer || !layer.geometry_data) return

    const geojson = typeof layer.geometry_data === "string"
      ? JSON.parse(layer.geometry_data)
      : layer.geometry_data

    const center = this.#geojsonCenter(geojson)
    if (center) {
      const mapCtrl = this.#mapController()
      if (mapCtrl) mapCtrl.panTo(center.lat, center.lng, undefined, { persist: false })
    }
  }

  // --- Private ---

  #enterPlacementMode(mapCtrl) {
    mapCtrl.enterPlacementMode()
    this.addButtonTarget.textContent = "Done"
    this.addButtonTarget.classList.replace("bg-blue-600", "bg-green-600")
    this.addButtonTarget.classList.replace("hover:bg-blue-500", "hover:bg-green-500")
    this.placementBannerTarget.classList.remove("hidden")
  }

  #exitPlacementMode(mapCtrl) {
    if (mapCtrl) {
      mapCtrl.placementMode = false
      mapCtrl.element.style.cursor = ""
    }
    this.addButtonTarget.textContent = "+ Add"
    this.addButtonTarget.classList.replace("bg-green-600", "bg-blue-600")
    this.addButtonTarget.classList.replace("hover:bg-green-500", "hover:bg-blue-500")
    this.placementBannerTarget.classList.add("hidden")
  }

  #appendMarkerToSidebar(marker) {
    const list = document.getElementById("markers_list")
    if (!list) return

    const item = document.createElement("div")
    item.id = `marker_${marker.id}`

    // Content row
    const content = document.createElement("div")
    content.dataset.role = "content"
    content.dataset.action = "dblclick->marker-editor#focusMarker"
    content.dataset.markerId = marker.id
    content.className = "flex items-center justify-between px-3 py-2 rounded-md hover:bg-gray-50 group cursor-pointer select-none"

    const left = document.createElement("div")
    left.className = "flex items-center gap-2 min-w-0"

    const dot = document.createElement("span")
    dot.className = "w-3 h-3 rounded-full shrink-0"
    dot.style.backgroundColor = marker.color || "#FF0000"

    const title = document.createElement("span")
    title.className = "text-sm font-medium truncate"
    title.textContent = marker.title || "Untitled Marker"

    left.appendChild(dot)
    left.appendChild(title)

    const right = document.createElement("div")
    right.className = "flex items-center gap-2 shrink-0 opacity-0 group-hover:opacity-100"

    const editLink = document.createElement("a")
    editLink.href = `/maps/${this.mapIdValue}/markers/${marker.id}/edit`
    editLink.dataset.turboFrame = "marker_form"
    editLink.className = "text-blue-600 hover:text-blue-800 text-xs font-medium"
    editLink.textContent = "Edit"

    const deleteLink = document.createElement("a")
    deleteLink.href = "#"
    deleteLink.dataset.action = "click->marker-editor#deleteMarker"
    deleteLink.dataset.markerEditorIdParam = marker.id
    deleteLink.className = "text-red-600 hover:text-red-800 text-xs font-medium cursor-pointer"
    deleteLink.textContent = "Delete"

    right.appendChild(editLink)
    right.appendChild(deleteLink)

    content.appendChild(left)
    content.appendChild(right)

    // Confirm bar
    const confirm = document.createElement("div")
    confirm.dataset.role = "confirm"
    confirm.className = "hidden flex items-center justify-between px-3 py-2 bg-red-50 rounded-md"

    const confirmText = document.createElement("span")
    confirmText.className = "text-sm text-red-700 font-medium"
    confirmText.textContent = "Delete marker?"

    const confirmButtons = document.createElement("div")
    confirmButtons.className = "flex gap-2"

    const cancelBtn = document.createElement("button")
    cancelBtn.dataset.action = "click->marker-editor#cancelDelete"
    cancelBtn.className = "text-xs font-medium text-gray-600 hover:text-gray-800 cursor-pointer"
    cancelBtn.textContent = "Cancel"

    const deleteBtn = document.createElement("button")
    deleteBtn.dataset.action = "click->marker-editor#confirmDeleteMarker"
    deleteBtn.dataset.markerEditorIdParam = marker.id
    deleteBtn.className = "text-xs font-medium text-white bg-red-600 hover:bg-red-500 rounded-md px-2.5 py-1 cursor-pointer"
    deleteBtn.textContent = "Delete"

    confirmButtons.appendChild(cancelBtn)
    confirmButtons.appendChild(deleteBtn)
    confirm.appendChild(confirmText)
    confirm.appendChild(confirmButtons)

    item.appendChild(content)
    item.appendChild(confirm)
    list.appendChild(item)
  }

  #showError(message, err) {
    console.error(message, err)
    const flash = document.createElement("div")
    flash.className = "fixed bottom-4 right-4 bg-red-600 text-white px-4 py-2 rounded-lg shadow-lg text-sm z-50"
    flash.textContent = message
    document.body.appendChild(flash)
    setTimeout(() => flash.remove(), 3000)
  }

  #mapController() {
    const mapEl = document.getElementById("map-canvas")
    return this.application.getControllerForElementAndIdentifier(mapEl, "map")
  }

  #drawingController() {
    const drawingEl = document.querySelector("[data-controller='drawing']")
    return this.application.getControllerForElementAndIdentifier(drawingEl, "drawing")
  }

  #geojsonCenter(geojson) {
    const coords = []

    const collect = (geometry) => {
      if (!geometry) return
      switch (geometry.type) {
        case "Point":
          coords.push(geometry.coordinates)
          break
        case "LineString":
          geometry.coordinates.forEach(c => coords.push(c))
          break
        case "Polygon":
          geometry.coordinates[0]?.forEach(c => coords.push(c))
          break
        case "Feature":
          collect(geometry.geometry)
          break
      }
    }

    collect(geojson)
    if (coords.length === 0) return null

    const sumLng = coords.reduce((s, c) => s + c[0], 0)
    const sumLat = coords.reduce((s, c) => s + c[1], 0)
    return { lat: sumLat / coords.length, lng: sumLng / coords.length }
  }
}
