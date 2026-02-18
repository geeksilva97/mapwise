import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"
import { getJSON, turboPatch } from "utils/http"
import { showError } from "utils/flash"

export default class extends Controller {
  static values = {
    mapId: Number,
    vehicles: { type: Array, default: [] },
    centerLat: { type: Number, default: 39.8283 },
    centerLng: { type: Number, default: -98.5795 },
    zoom: { type: Number, default: 4 },
    styleJson: { type: String, default: "" },
    googleMapId: { type: String, default: "" }
  }

  static targets = ["map"]

  connect() {
    this.vehicleMarkers = new Map()   // vehicleId → google.maps.Marker
    this.vehicleTrails = new Map()    // vehicleId → google.maps.Polyline
    this.plannedPaths = new Map()     // vehicleId → google.maps.Polyline
    this.waitForGoogleMaps()
  }

  disconnect() {
    if (this._waitTimer) {
      clearTimeout(this._waitTimer)
      this._waitTimer = null
    }
    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }
  }

  waitForGoogleMaps() {
    if (window.google?.maps?.Map) {
      this.initMap()
    } else {
      this._waitTimer = setTimeout(() => this.waitForGoogleMaps(), 100)
    }
  }

  async initMap() {
    const { Map } = await google.maps.importLibrary("maps")

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
      } catch (e) { /* ignore */ }
    }

    this.map = new Map(this.mapTarget, mapOptions)
    this._hasFitted = false

    // Render initial vehicles (planned paths + last known position)
    const inits = this.vehiclesValue.map(v => this.#initVehicle(v))
    Promise.all(inits).then(() => this.#fitToAllVehicles())

    // Subscribe to Action Cable
    this.#subscribe()
  }

  focusVehicle(event) {
    const vehicleId = parseInt(event.currentTarget.dataset.vehicleId)
    if (!vehicleId || !this.map) return

    const bounds = new google.maps.LatLngBounds()
    let hasPoints = false

    // Include trail points
    const trail = this.vehicleTrails.get(vehicleId)
    if (trail) {
      trail.getPath().forEach(p => {
        bounds.extend(p)
        hasPoints = true
      })
    }

    // Include current marker position
    const marker = this.vehicleMarkers.get(vehicleId)
    if (marker) {
      bounds.extend(marker.getPosition())
      hasPoints = true
    }

    // Include planned path
    const planned = this.plannedPaths.get(vehicleId)
    if (planned) {
      planned.getPath().forEach(p => {
        bounds.extend(p)
        hasPoints = true
      })
    }

    if (hasPoints) {
      this.map.fitBounds(bounds, { top: 50, bottom: 50, left: 50, right: 50 })
    }
  }

  acknowledgeAlert(event) {
    const alertId = event.currentTarget.dataset.alertId
    turboPatch(`/maps/${this.mapIdValue}/deviation_alerts/${alertId}/acknowledge`)
      .then(html => {
        document.documentElement.insertAdjacentHTML("beforeend", html)
      }).catch(err => showError("Failed to acknowledge alert.", err))
  }

  // --- Private ---

  async #initVehicle(vehicle) {
    const color = vehicle.color || "#3B82F6"

    // Render planned path if present
    if (vehicle.planned_path) {
      try {
        const data = JSON.parse(vehicle.planned_path)
        const coords = data.type === "Feature"
          ? data.geometry.coordinates
          : data.coordinates || []

        const path = coords.map(c => ({ lat: c[1], lng: c[0] }))
        const polyline = new google.maps.Polyline({
          path,
          map: this.map,
          strokeColor: color,
          strokeOpacity: 0.4,
          strokeWeight: 3,
          icons: [{
            icon: { path: "M 0,-1 0,1", strokeOpacity: 1, scale: 3 },
            offset: "0",
            repeat: "15px"
          }]
        })
        this.plannedPaths.set(vehicle.id, polyline)
      } catch (e) {
        console.warn("Failed to render planned path:", e)
      }
    }

    // Fetch recent historical points and render trail + last position marker
    try {
      const points = await getJSON(
        `/maps/${this.mapIdValue}/tracked_vehicles/${vehicle.id}/points?from=${new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()}&limit=5000`
      )
      const trailPath = points.map(p => ({ lat: p.lat, lng: p.lng }))

      const trail = new google.maps.Polyline({
        path: trailPath,
        map: this.map,
        strokeColor: color,
        strokeOpacity: 0.8,
        strokeWeight: 3
      })
      this.vehicleTrails.set(vehicle.id, trail)

      // Place marker at last known position
      if (points.length > 0) {
        const last = points[points.length - 1]
        const marker = new google.maps.Marker({
          map: this.map,
          position: { lat: last.lat, lng: last.lng },
          icon: this.#vehicleIcon(color),
          title: vehicle.name || ""
        })
        this.vehicleMarkers.set(vehicle.id, marker)
      }
    } catch (e) {
      // Fallback: create empty trail for real-time points
      const trail = new google.maps.Polyline({
        path: [],
        map: this.map,
        strokeColor: color,
        strokeOpacity: 0.8,
        strokeWeight: 3
      })
      this.vehicleTrails.set(vehicle.id, trail)
    }
  }

  #subscribe() {
    this.subscription = consumer.subscriptions.create(
      { channel: "TrackingChannel", map_id: this.mapIdValue },
      {
        received: (data) => this.#handleMessage(data)
      }
    )
  }

  #handleMessage(data) {
    if (data.type === "tracking_point") {
      this.#updateVehiclePosition(data)
    } else if (data.type === "deviation_alert") {
      this.#showDeviationAlert(data)
    }
  }

  #fitToAllVehicles() {
    const bounds = new google.maps.LatLngBounds()
    let hasPoints = false

    this.vehicleTrails.forEach(trail => {
      trail.getPath().forEach(p => { bounds.extend(p); hasPoints = true })
    })
    this.vehicleMarkers.forEach(marker => {
      bounds.extend(marker.getPosition()); hasPoints = true
    })

    if (hasPoints) {
      this.map.fitBounds(bounds, { top: 50, bottom: 50, left: 50, right: 50 })
      this._hasFitted = true
    }
  }

  #updateVehiclePosition(data) {
    const { vehicle_id, vehicle_color, point } = data
    const position = { lat: point.lat, lng: point.lng }

    // Update or create position marker
    let marker = this.vehicleMarkers.get(vehicle_id)
    if (marker) {
      marker.setPosition(position)
    } else {
      marker = new google.maps.Marker({
        map: this.map,
        position,
        icon: this.#vehicleIcon(vehicle_color || "#3B82F6"),
        title: data.vehicle_name || ""
      })
      this.vehicleMarkers.set(vehicle_id, marker)
    }

    // Extend trail
    const trail = this.vehicleTrails.get(vehicle_id)
    if (trail) {
      trail.getPath().push(new google.maps.LatLng(point.lat, point.lng))
    }

    // Auto-zoom on first real-time point, then pan to follow
    if (!this._hasFitted) {
      this.map.setCenter(position)
      this.map.setZoom(15)
      this._hasFitted = true
    } else if (!this.map.getBounds()?.contains(position)) {
      this.map.panTo(position)
    }

    // Update sidebar live vehicle list
    this.#updateLiveVehicleItem(vehicle_id, point)
  }

  #showDeviationAlert(data) {
    const alertsList = document.getElementById("alerts_list")
    if (!alertsList) return

    // Remove "no alerts" message
    const empty = alertsList.querySelector("p.text-gray-400")
    if (empty) empty.remove()

    const alertEl = document.createElement("div")
    alertEl.id = `alert_${data.alert.id}`
    alertEl.className = "rounded-lg border border-amber-200 bg-amber-50 px-3 py-2.5"
    alertEl.innerHTML = `
      <div class="flex items-start justify-between gap-2">
        <div class="min-w-0">
          <p class="text-sm font-medium text-amber-800">${this.#escapeHtml(data.vehicle_name)}</p>
          <p class="text-xs text-amber-600 mt-0.5">${this.#escapeHtml(data.alert.message || `Deviated ${data.alert.distance_meters}m from path`)}</p>
          <p class="text-xs text-amber-400 mt-1">Just now</p>
        </div>
        <button type="button"
                data-action="click->tracking#acknowledgeAlert"
                data-alert-id="${data.alert.id}"
                class="shrink-0 text-xs font-medium text-amber-700 hover:text-amber-900 cursor-pointer">
          Dismiss
        </button>
      </div>
    `
    alertsList.prepend(alertEl)
  }

  #updateLiveVehicleItem(vehicleId, point) {
    const el = document.getElementById(`live_vehicle_${vehicleId}`)
    if (!el) return

    const infoP = el.querySelector("p.text-xs")
    if (infoP) {
      const speed = point.speed != null ? `${Number(point.speed).toFixed(1)} km/h` : "No speed"
      infoP.textContent = `${speed} \u00B7 Just now`
    }
  }

  #vehicleIcon(color) {
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">` +
      `<circle cx="12" cy="12" r="10" fill="${color}" stroke="white" stroke-width="2"/>` +
      `<circle cx="12" cy="12" r="4" fill="white"/>` +
      `</svg>`

    return {
      url: "data:image/svg+xml;charset=UTF-8," + encodeURIComponent(svg),
      scaledSize: new google.maps.Size(24, 24),
      anchor: new google.maps.Point(12, 12)
    }
  }

  #escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
