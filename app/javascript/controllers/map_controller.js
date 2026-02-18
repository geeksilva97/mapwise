import { Controller } from "@hotwired/stimulus"

// Two rendering modes based on google_map_id presence:
//   With google_map_id → mapId set → AdvancedMarkerElement, cloud-based styling
//   Without google_map_id → no mapId → legacy Marker with SVG icons, JSON styles

export default class extends Controller {
  static targets = ["markerSync"]
  static values = {
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
    this.markerById = new Map()    // markerId → { gmMarker, data }
    this.markerInfoMap = new Map() // markerId → { marker, infoWindow }
    this.markerClusterer = null
    this.placementMode = false
    this.circleSelectionMode = false
    this.waitForGoogleMaps()
  }

  disconnect() {
    if (this._waitTimer) {
      clearTimeout(this._waitTimer)
      this._waitTimer = null
    }
    this.markerById.forEach(({ gmMarker }) => {
      if (this.useAdvancedMarkers) {
        gmMarker.map = null
      } else {
        gmMarker.setMap(null)
      }
    })
    this.markerById.clear()
    if (this.markerClusterer) {
      this.markerClusterer.clearMarkers()
      this.markerClusterer = null
    }
  }

  markerSyncTargetConnected(el) {
    this.markersValue = JSON.parse(el.dataset.markers)
    el.remove()
  }

  waitForGoogleMaps() {
    if (window.google?.maps?.Map) {
      this.initMap()
    } else {
      // Script is in the layout with async/defer — poll until ready
      this._waitTimer = setTimeout(() => this.waitForGoogleMaps(), 100)
    }
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
    // Map click for marker placement
    this.map.addListener("click", (event) => {
      if (this.placementMode) {
        this.dispatch("markerPlaced", {
          detail: { lat: event.latLng.lat(), lng: event.latLng.lng() }
        })
      }
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

  // Re-render markers when groups change (visibility toggle)
  groupsValueChanged() {
    if (this.map) {
      this.renderMarkers()
    }
  }

  // Rebuild clustering without full diff when only clustering mode changed
  clusteringEnabledValueChanged() {
    if (this.map) {
      this.#rebuildClustering()
    }
  }

  renderMarkers() {
    // Build a set of hidden group IDs
    const hiddenGroupIds = new Set(
      this.groupsValue
        .filter(g => !g.visible)
        .map(g => g.id)
    )

    // Build map of visible markers
    const visibleMarkers = new Map()
    this.markersValue.forEach(markerData => {
      if (markerData.marker_group_id && hiddenGroupIds.has(markerData.marker_group_id)) {
        return
      }
      visibleMarkers.set(markerData.id, markerData)
    })

    // Compute diff
    const toAdd = []
    const toRemove = []
    const toUpdate = []

    visibleMarkers.forEach((data, id) => {
      const existing = this.markerById.get(id)
      if (!existing) {
        toAdd.push(data)
      } else if (this.#markerNeedsUpdate(existing.data, data)) {
        toUpdate.push({ existing, data })
      }
    })

    this.markerById.forEach((entry, id) => {
      if (!visibleMarkers.has(id)) {
        toRemove.push({ id, gmMarker: entry.gmMarker })
      }
    })

    if (toAdd.length === 0 && toRemove.length === 0 && toUpdate.length === 0) return

    const setChanged = toAdd.length > 0 || toRemove.length > 0

    // Remove
    toRemove.forEach(({ id, gmMarker }) => {
      if (this.useAdvancedMarkers) {
        gmMarker.map = null
      } else {
        gmMarker.setMap(null)
      }
      this.markerById.delete(id)
      this.markerInfoMap.delete(id)
    })

    // Update in place
    toUpdate.forEach(({ existing, data }) => {
      const { gmMarker } = existing

      if (data.lat !== existing.data.lat || data.lng !== existing.data.lng) {
        if (this.useAdvancedMarkers) {
          gmMarker.position = { lat: data.lat, lng: data.lng }
        } else {
          gmMarker.setPosition({ lat: data.lat, lng: data.lng })
        }
      }

      if (data.title !== existing.data.title) {
        gmMarker.title = data.title || ""
      }

      if (data.color !== existing.data.color) {
        if (this.useAdvancedMarkers) {
          const pinGlyph = new google.maps.marker.PinElement({
            background: data.color || "#FF0000",
            borderColor: data.color || "#FF0000",
            glyphColor: "#FFFFFF"
          })
          gmMarker.content = pinGlyph.element
        } else {
          gmMarker.setIcon(this.#markerIcon(data.color))
        }
      }

      // Update info window if content changed (readonly only)
      if (this.readonlyValue) {
        const infoChanged = data.title !== existing.data.title ||
                           data.description !== existing.data.description ||
                           data.custom_info_html !== existing.data.custom_info_html
        if (infoChanged) {
          this.#setupInfoWindow(gmMarker, data)
        }
      }

      existing.data = data
    })

    // Add (created without map — #rebuildClustering handles placement)
    toAdd.forEach(markerData => {
      const gmMarker = this.useAdvancedMarkers
        ? this.#createAdvancedMarker(markerData, false)
        : this.#createLegacyMarker(markerData, false)

      this.#attachMarkerListeners(gmMarker, markerData)
      this.markerById.set(markerData.id, { gmMarker, data: markerData })
    })

    // Rebuild clustering when marker set changes
    if (setChanged) {
      this.#rebuildClustering()
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

  // Pan the map to given coordinates and optionally set zoom
  panTo(lat, lng, zoom) {
    if (!this.map) return
    this.map.panTo({ lat, lng })
    if (zoom !== undefined) this.map.setZoom(zoom)
  }

  // Pan to a marker by ID and open its info window
  openInfoWindowForMarker(markerId) {
    const entry = this.markerInfoMap.get(markerId)
    if (!entry) return

    const { marker, infoWindow } = entry
    const pos = this.useAdvancedMarkers ? marker.position : marker.getPosition()
    this.map.panTo(pos)
    infoWindow.open({ anchor: marker, map: this.map })
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

  #markerNeedsUpdate(oldData, newData) {
    return oldData.lat !== newData.lat ||
           oldData.lng !== newData.lng ||
           oldData.title !== newData.title ||
           oldData.color !== newData.color ||
           oldData.description !== newData.description ||
           oldData.custom_info_html !== newData.custom_info_html
  }

  #attachMarkerListeners(gmMarker, markerData) {
    if (!this.readonlyValue) {
      if (this.useAdvancedMarkers) {
        gmMarker.addListener("dragend", () => {
          const pos = gmMarker.position
          this.dispatch("markerDragged", {
            detail: { id: markerData.id, lat: pos.lat, lng: pos.lng }
          })
        })
      } else {
        gmMarker.addListener("dragend", (event) => {
          this.dispatch("markerDragged", {
            detail: { id: markerData.id, lat: event.latLng.lat(), lng: event.latLng.lng() }
          })
        })
      }

      gmMarker.addListener("click", () => {
        this.dispatch("markerClicked", { detail: { id: markerData.id } })
      })
    }

    if (this.readonlyValue) {
      // Single click handler that dynamically looks up current info window
      gmMarker.addListener("click", () => {
        const entry = this.markerInfoMap.get(markerData.id)
        if (entry) {
          entry.infoWindow.open({ anchor: gmMarker, map: this.map })
        }
      })
      this.#setupInfoWindow(gmMarker, markerData)
    }
  }

  #setupInfoWindow(gmMarker, markerData) {
    if (!markerData.title && !markerData.custom_info_html) {
      this.markerInfoMap.delete(markerData.id)
      return
    }

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
    this.markerInfoMap.set(markerData.id, { marker: gmMarker, infoWindow })
  }

  #rebuildClustering() {
    if (this.markerClusterer) {
      this.markerClusterer.clearMarkers()
      this.markerClusterer = null
    }

    const allMarkers = [...this.markerById.values()].map(({ gmMarker }) => gmMarker)

    if (this.clusteringEnabledValue && allMarkers.length > 0) {
      allMarkers.forEach(m => {
        if (this.useAdvancedMarkers) {
          m.map = null
        } else {
          m.setMap(null)
        }
      })
      this.#applyClustering(allMarkers)
    } else {
      allMarkers.forEach(m => {
        if (this.useAdvancedMarkers) {
          m.map = this.map
        } else {
          m.setMap(this.map)
        }
      })
    }
  }

  async #applyClustering(markers) {
    try {
      const { MarkerClusterer } = await import("@googlemaps/markerclusterer")
      this.markerClusterer = new MarkerClusterer({
        map: this.map,
        markers
      })
    } catch (e) {
      console.warn("MarkerClusterer not available, adding markers directly:", e)
      markers.forEach(m => {
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
