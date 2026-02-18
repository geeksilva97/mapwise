import { Controller } from "@hotwired/stimulus"
import { getJSON } from "utils/http"

export default class extends Controller {
  static values = { mapId: Number }
  static targets = [
    "vehicleSelect", "fromInput", "toInput", "speedSelect",
    "playBtn", "stopBtn", "progressContainer", "progressBar", "progressLabel"
  ]

  connect() {
    this.points = []
    this.currentIndex = 0
    this.playing = false
    this.animationTimer = null
    this.playbackMarker = null
    this.playbackTrail = null
  }

  disconnect() {
    this.#stopPlayback()
  }

  async load() {
    const vehicleId = this.vehicleSelectTarget.value
    if (!vehicleId) return

    const from = this.fromInputTarget.value
    const to = this.toInputTarget.value

    const params = new URLSearchParams()
    if (from) params.set("from", new Date(from).toISOString())
    if (to) params.set("to", new Date(to).toISOString())

    try {
      this.points = await getJSON(
        `/maps/${this.mapIdValue}/tracked_vehicles/${vehicleId}/points?${params}`
      )
      this.currentIndex = 0

      if (this.points.length === 0) {
        this.progressLabelTarget.textContent = "No points found"
        this.progressContainerTarget.classList.remove("hidden")
        this.playBtnTarget.disabled = true
        this.stopBtnTarget.disabled = true
        return
      }

      this.playBtnTarget.disabled = false
      this.stopBtnTarget.disabled = false
      this.progressContainerTarget.classList.remove("hidden")
      this.#updateProgress()

      // Dispatch to the tracking controller to set up playback visuals
      this.dispatch("loaded", {
        detail: { vehicleId: parseInt(vehicleId), points: this.points }
      })
    } catch (e) {
      console.error("Failed to load playback points:", e)
    }
  }

  playPause() {
    if (this.playing) {
      this.#pause()
    } else {
      this.#play()
    }
  }

  stop() {
    this.#stopPlayback()
    this.currentIndex = 0
    this.#updateProgress()
    this.playBtnTarget.textContent = "Play"
    this.playing = false

    // Clean up playback markers on tracking map
    this.#cleanupPlaybackVisuals()
  }

  // --- Private ---

  #play() {
    if (this.currentIndex >= this.points.length) {
      this.currentIndex = 0
    }

    this.playing = true
    this.playBtnTarget.textContent = "Pause"
    this.#tick()
  }

  #pause() {
    this.playing = false
    this.playBtnTarget.textContent = "Play"
    if (this.animationTimer) {
      clearTimeout(this.animationTimer)
      this.animationTimer = null
    }
  }

  #stopPlayback() {
    this.playing = false
    if (this.animationTimer) {
      clearTimeout(this.animationTimer)
      this.animationTimer = null
    }
  }

  #tick() {
    if (!this.playing || this.currentIndex >= this.points.length) {
      this.#pause()
      return
    }

    const point = this.points[this.currentIndex]
    this.#renderPlaybackPoint(point)
    this.currentIndex++
    this.#updateProgress()

    const speed = parseInt(this.speedSelectTarget.value) || 5
    const delay = 1000 / speed

    this.animationTimer = setTimeout(() => this.#tick(), delay)
  }

  #renderPlaybackPoint(point) {
    const trackingEl = document.querySelector("[data-controller~='tracking']")
    if (!trackingEl) return

    const trackingCtrl = this.application.getControllerForElementAndIdentifier(trackingEl, "tracking")
    if (!trackingCtrl || !trackingCtrl.map) return

    const position = { lat: point.lat, lng: point.lng }

    // Create or move the playback marker
    if (this.playbackMarker) {
      this.playbackMarker.setPosition(position)
    } else {
      this.playbackMarker = new google.maps.Marker({
        map: trackingCtrl.map,
        position,
        icon: {
          path: google.maps.SymbolPath.CIRCLE,
          scale: 8,
          fillColor: "#8B5CF6",
          fillOpacity: 1,
          strokeColor: "#FFFFFF",
          strokeWeight: 2
        },
        zIndex: 999
      })
    }

    // Extend trail
    if (!this.playbackTrail) {
      this.playbackTrail = new google.maps.Polyline({
        path: [position],
        map: trackingCtrl.map,
        strokeColor: "#8B5CF6",
        strokeOpacity: 0.8,
        strokeWeight: 3
      })
    } else {
      this.playbackTrail.getPath().push(new google.maps.LatLng(point.lat, point.lng))
    }

    // Pan map to follow
    trackingCtrl.map.panTo(position)
  }

  #cleanupPlaybackVisuals() {
    if (this.playbackMarker) {
      this.playbackMarker.setMap(null)
      this.playbackMarker = null
    }
    if (this.playbackTrail) {
      this.playbackTrail.setMap(null)
      this.playbackTrail = null
    }
  }

  #updateProgress() {
    const pct = this.points.length > 0
      ? (this.currentIndex / this.points.length) * 100
      : 0
    this.progressBarTarget.style.width = `${pct}%`
    this.progressLabelTarget.textContent = `${this.currentIndex} / ${this.points.length} points`
  }
}
