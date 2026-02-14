import { Controller } from "@hotwired/stimulus"

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
    await google.maps.importLibrary("marker")

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
    const csrfToken = document.querySelector("[name='csrf-token']")?.content

    fetch(`/maps/${this.idValue}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken
      },
      body: JSON.stringify({
        map: {
          center_lat: center.lat(),
          center_lng: center.lng(),
          zoom: this.map.getZoom()
        }
      })
    })
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
    this.mapMarkers.forEach(m => m.map = null)
    this.mapMarkers = []

    this.markersValue.forEach(markerData => {
      const pinGlyph = new google.maps.marker.PinElement({
        background: markerData.color || "#FF0000",
        borderColor: markerData.color || "#FF0000",
        glyphColor: "#FFFFFF"
      })

      const marker = new google.maps.marker.AdvancedMarkerElement({
        map: this.map,
        position: { lat: markerData.lat, lng: markerData.lng },
        title: markerData.title || "",
        content: pinGlyph.element,
        gmpDraggable: !this.readonlyValue
      })

      if (!this.readonlyValue) {
        marker.addListener("dragend", () => {
          const pos = marker.position
          this.dispatch("markerDragged", {
            detail: { id: markerData.id, lat: pos.lat, lng: pos.lng }
          })
        })

        marker.addListener("click", () => {
          this.dispatch("markerClicked", { detail: { id: markerData.id } })
        })
      }

      // Info window for viewer/read-only mode
      if (this.readonlyValue && markerData.title) {
        const infoWindow = new google.maps.InfoWindow({
          content: `<div class="p-2"><strong>${markerData.title}</strong>${markerData.description ? `<p>${markerData.description}</p>` : ""}</div>`
        })

        marker.addListener("click", () => {
          infoWindow.open({ anchor: marker, map: this.map })
        })
      }

      this.mapMarkers.push(marker)
    })
  }

  // Apply a style JSON string
  applyStyle(styleJson) {
    if (!this.map) return

    try {
      const styles = JSON.parse(styleJson)
      this.map.setOptions({ styles })
    } catch (e) {
      // ignore invalid JSON
    }
  }
}
