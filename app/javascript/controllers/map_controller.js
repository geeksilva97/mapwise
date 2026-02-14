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
    styleJson: { type: String, default: "" },
    googleMapId: { type: String, default: "" }
  }

  connect() {
    this.mapMarkers = []
    this.placementMode = false
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
      script.src = `https://maps.googleapis.com/maps/api/js?key=${this.apiKeyValue}&libraries=marker,places&v=weekly`
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

  renderMarkers() {
    // Clear existing markers
    this.mapMarkers.forEach(m => {
      if (this.useAdvancedMarkers) {
        m.map = null
      } else {
        m.setMap(null)
      }
    })
    this.mapMarkers = []

    this.markersValue.forEach(markerData => {
      const marker = this.useAdvancedMarkers
        ? this.#createAdvancedMarker(markerData)
        : this.#createLegacyMarker(markerData)

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
      if (this.readonlyValue && markerData.title) {
        const infoContent = document.createElement("div")
        infoContent.className = "p-2"

        const strong = document.createElement("strong")
        strong.textContent = markerData.title
        infoContent.appendChild(strong)

        if (markerData.description) {
          const p = document.createElement("p")
          p.textContent = markerData.description
          infoContent.appendChild(p)
        }

        const infoWindow = new google.maps.InfoWindow({ content: infoContent })

        marker.addListener("click", () => {
          infoWindow.open({ anchor: marker, map: this.map })
        })
      }

      this.mapMarkers.push(marker)
    })
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

  #createAdvancedMarker(markerData) {
    const pinGlyph = new google.maps.marker.PinElement({
      background: markerData.color || "#FF0000",
      borderColor: markerData.color || "#FF0000",
      glyphColor: "#FFFFFF"
    })

    return new google.maps.marker.AdvancedMarkerElement({
      map: this.map,
      position: { lat: markerData.lat, lng: markerData.lng },
      title: markerData.title || "",
      content: pinGlyph.element,
      gmpDraggable: !this.readonlyValue
    })
  }

  #createLegacyMarker(markerData) {
    return new google.maps.Marker({
      map: this.map,
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
