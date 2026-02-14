import { Controller } from "@hotwired/stimulus"
import { csrfToken } from "utils/csrf"

// Two rendering modes based on google_map_id presence:
//   With google_map_id → mapId set → AdvancedMarkerElement, cloud-based styling
//   Without google_map_id → no mapId → legacy Marker with SVG icons, JSON styles

export default class extends Controller {
  static values = {
    apiKey: String,
    centerLat: { type: Number, default: 0 },
    centerLng: { type: Number, default: 0 },
    zoom: { type: Number, default: 3 },
    id: { type: Number, default: 0 },
    readonly: { type: Boolean, default: true },
    markers: { type: Array, default: [] },
    groups: { type: Array, default: [] },
    clusteringEnabled: { type: Boolean, default: false },
    styleJson: { type: String, default: "" },
    googleMapId: { type: String, default: "" }
  }

  connect() {
    this.mapMarkers = []
    this.markerClusterer = null
    this.placementMode = false
    this.circleSelectionMode = false
    this.loadGoogleMaps()
  }

  disconnect() {
    if (this.saveTimeout) clearTimeout(this.saveTimeout)
  }

  async loadGoogleMaps() {
    if (window.google?.maps?.Map) {
      this.initMap()
      return
    }

    return new Promise((resolve) => {
      const script = document.createElement("script")
      script.src = `https://maps.googleapis.com/maps/api/js?key=${this.apiKeyValue}&libraries=marker,places,geometry&v=weekly`
      script.async = true
      script.defer = true
      script.onload = () => {
        this.initMap()
        resolve()
      }
      document.head.appendChild(script)
    })
  }

  async initMap() {
    const { Map } = await google.maps.importLibrary("maps")

    this.useAdvancedMarkers = !!this.googleMapIdValue

    if (this.useAdvancedMarkers) {
      await google.maps.importLibrary("marker")
    }

    const mapOptions = {
      center: { lat: this.centerLatValue, lng: this.centerLngValue },
      zoom: this.zoomValue,
      mapTypeId: "roadmap"
    }

    if (this.googleMapIdValue) {
      mapOptions.mapId = this.googleMapIdValue
    } else if (this.styleJsonValue) {
      try {
        mapOptions.styles = JSON.parse(this.styleJsonValue)
      } catch (e) { /* ignore invalid JSON */ }
    }

    this.map = new Map(this.element, mapOptions)
    this.renderMarkers()

    if (!this.readonlyValue) {
      this.setupEditorEvents()
    }
  }

  setupEditorEvents() {
    // Persist center/zoom on idle (debounced)
    this.map.addListener("idle", () => {
      if (this.saveTimeout) clearTimeout(this.saveTimeout)
      this.saveTimeout = setTimeout(() => this.persistMapState(), 1000)
    })

    // Map click for marker placement
    this.map.addListener("click", (event) => {
      if (this.placementMode) {
        this.dispatch("markerPlaced", {
          detail: { lat: event.latLng.lat(), lng: event.latLng.lng() }
        })
        this.placementMode = false
        this.element.style.cursor = ""
      }
    })
  }

  persistMapState() {
    if (!this.idValue) return

    const center = this.map.getCenter()

    fetch(`/maps/${this.idValue}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken()
      },
      body: JSON.stringify({
        map: {
          center_lat: center.lat(),
          center_lng: center.lng(),
          zoom: this.map.getZoom()
        }
      })
    })
      .catch(err => console.error("Failed to save map state:", err))
  }

  // Called by external Stimulus actions to enter placement mode
  enterPlacementMode() {
    this.placementMode = true
    this.element.style.cursor = "crosshair"
  }

  // Re-render markers when the markers value changes
  markersValueChanged() {
    if (this.map) {
      this.renderMarkers()
    }
  }

  // Re-render markers when groups change (visibility toggle)
  groupsValueChanged() {
    if (this.map) {
      this.renderMarkers()
    }
  }

  // Re-render markers when clustering is toggled
  clusteringEnabledValueChanged() {
    if (this.map) {
      this.renderMarkers()
    }
  }

  renderMarkers() {
    // Clear existing clusterer
    if (this.markerClusterer) {
      this.markerClusterer.clearMarkers()
      this.markerClusterer = null
    }

    // Clear existing markers
    this.mapMarkers.forEach(m => {
      if (this.useAdvancedMarkers) {
        m.map = null
      } else {
        m.setMap(null)
      }
    })
    this.mapMarkers = []

    // Build a set of hidden group IDs
    const hiddenGroupIds = new Set(
      this.groupsValue
        .filter(g => !g.visible)
        .map(g => g.id)
    )

    const addToMap = !this.clusteringEnabledValue

    this.markersValue.forEach(markerData => {
      // Skip markers whose group is hidden
      if (markerData.marker_group_id && hiddenGroupIds.has(markerData.marker_group_id)) {
        return
      }

      const marker = this.useAdvancedMarkers
        ? this.#createAdvancedMarker(markerData, addToMap)
        : this.#createLegacyMarker(markerData, addToMap)

      if (!this.readonlyValue) {
        if (this.useAdvancedMarkers) {
          marker.addListener("dragend", () => {
            const pos = marker.position
            this.dispatch("markerDragged", {
              detail: { id: markerData.id, lat: pos.lat, lng: pos.lng }
            })
          })
        } else {
          marker.addListener("dragend", (event) => {
            this.dispatch("markerDragged", {
              detail: { id: markerData.id, lat: event.latLng.lat(), lng: event.latLng.lng() }
            })
          })
        }

        marker.addListener("click", () => {
          this.dispatch("markerClicked", { detail: { id: markerData.id } })
        })
      }

      // Info window for viewer/read-only mode
      if (this.readonlyValue && (markerData.title || markerData.custom_info_html)) {
        const infoContent = document.createElement("div")
        infoContent.className = "p-2"

        if (markerData.custom_info_html) {
          infoContent.innerHTML = markerData.custom_info_html
        } else {
          const strong = document.createElement("strong")
          strong.textContent = markerData.title
          infoContent.appendChild(strong)

          if (markerData.description) {
            const p = document.createElement("p")
            p.textContent = markerData.description
            infoContent.appendChild(p)
          }
        }

        const infoWindow = new google.maps.InfoWindow({ content: infoContent })

        marker.addListener("click", () => {
          infoWindow.open({ anchor: marker, map: this.map })
        })
      }

      this.mapMarkers.push(marker)
    })

    // Apply clustering if enabled
    if (this.clusteringEnabledValue && this.mapMarkers.length > 0) {
      this.#applyClustering()
    }
  }

  // Circle selection: draw a circle to select enclosed markers
  enterCircleSelectionMode(callback) {
    this.circleSelectionMode = true
    this.circleCallback = callback
    this.map.setOptions({ draggable: false })
    this.element.style.cursor = "crosshair"
    this.dispatch("circleSelectionStarted")

    this._circleMouseDown = (event) => {
      this._circleCenter = event.latLng
      this._selectionCircle = new google.maps.Circle({
        map: this.map,
        center: event.latLng,
        radius: 0,
        fillColor: "#3B82F6",
        fillOpacity: 0.15,
        strokeColor: "#3B82F6",
        strokeWeight: 2,
        clickable: false
      })
    }

    this._circleMouseMove = (event) => {
      if (!this._selectionCircle || !this._circleCenter) return
      const radius = google.maps.geometry.spherical.computeDistanceBetween(
        this._circleCenter, event.latLng
      )
      this._selectionCircle.setRadius(radius)
    }

    this._circleMouseUp = () => {
      if (!this._selectionCircle || !this._circleCenter) return

      const center = this._circleCenter
      const radius = this._selectionCircle.getRadius()

      // Find enclosed markers
      const enclosedIds = this.markersValue
        .filter(m => {
          const pos = new google.maps.LatLng(m.lat, m.lng)
          const dist = google.maps.geometry.spherical.computeDistanceBetween(center, pos)
          return dist <= radius
        })
        .map(m => m.id)

      // Grab callback before cleanup nulls it
      const callback = this.circleCallback

      // Clean up
      this._selectionCircle.setMap(null)
      this._selectionCircle = null
      this._circleCenter = null
      this.exitCircleSelectionMode()

      if (callback) {
        callback(enclosedIds)
      }
    }

    this._circleDownListener = this.map.addListener("mousedown", this._circleMouseDown)
    this._circleMoveListener = this.map.addListener("mousemove", this._circleMouseMove)
    // Use DOM mouseup — Google Maps mouseup is unreliable when draggable is false
    this._circleUpHandler = this._circleMouseUp
    this.element.addEventListener("mouseup", this._circleUpHandler)
  }

  exitCircleSelectionMode() {
    this.circleSelectionMode = false
    this.circleCallback = null
    this.map.setOptions({ draggable: true })
    this.element.style.cursor = ""
    this.dispatch("circleSelectionEnded")

    if (this._selectionCircle) {
      this._selectionCircle.setMap(null)
      this._selectionCircle = null
    }
    this._circleCenter = null

    if (this._circleDownListener) {
      google.maps.event.removeListener(this._circleDownListener)
      this._circleDownListener = null
    }
    if (this._circleMoveListener) {
      google.maps.event.removeListener(this._circleMoveListener)
      this._circleMoveListener = null
    }
    if (this._circleUpHandler) {
      this.element.removeEventListener("mouseup", this._circleUpHandler)
      this._circleUpHandler = null
    }
  }

  // Apply a style JSON string (only works in legacy mode — no mapId)
  applyStyle(styleJson) {
    if (!this.map || this.useAdvancedMarkers) return

    try {
      const styles = JSON.parse(styleJson)
      this.map.setOptions({ styles })
    } catch (e) {
      // ignore invalid JSON
    }
  }

  // --- Private ---

  async #applyClustering() {
    try {
      const { MarkerClusterer } = await import("@googlemaps/markerclusterer")
      this.markerClusterer = new MarkerClusterer({
        map: this.map,
        markers: this.mapMarkers
      })
    } catch (e) {
      console.warn("MarkerClusterer not available, adding markers directly:", e)
      this.mapMarkers.forEach(m => {
        if (this.useAdvancedMarkers) {
          m.map = this.map
        } else {
          m.setMap(this.map)
        }
      })
    }
  }

  #createAdvancedMarker(markerData, addToMap = true) {
    const pinGlyph = new google.maps.marker.PinElement({
      background: markerData.color || "#FF0000",
      borderColor: markerData.color || "#FF0000",
      glyphColor: "#FFFFFF"
    })

    return new google.maps.marker.AdvancedMarkerElement({
      map: addToMap ? this.map : null,
      position: { lat: markerData.lat, lng: markerData.lng },
      title: markerData.title || "",
      content: pinGlyph.element,
      gmpDraggable: !this.readonlyValue
    })
  }

  #createLegacyMarker(markerData, addToMap = true) {
    return new google.maps.Marker({
      map: addToMap ? this.map : null,
      position: { lat: markerData.lat, lng: markerData.lng },
      title: markerData.title || "",
      draggable: !this.readonlyValue,
      icon: this.#markerIcon(markerData.color)
    })
  }

  #markerIcon(color) {
    const safeColor = /^#[0-9A-Fa-f]{6}$/.test(color) ? color : "#FF0000"
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="28" height="40" viewBox="0 0 28 40">` +
      `<path d="M14 0C6.3 0 0 6.3 0 14c0 10.5 14 26 14 26s14-15.5 14-26C28 6.3 21.7 0 14 0z" fill="${safeColor}" stroke="white" stroke-width="1.5"/>` +
      `<circle cx="14" cy="14" r="5" fill="white" opacity="0.9"/>` +
      `</svg>`

    return {
      url: "data:image/svg+xml;charset=UTF-8," + encodeURIComponent(svg),
      scaledSize: new google.maps.Size(28, 40),
      anchor: new google.maps.Point(14, 40)
    }
  }
}
