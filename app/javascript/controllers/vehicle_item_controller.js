import { Controller } from "@hotwired/stimulus"
import { turboPatch, turboDelete, turboGet } from "utils/http"
import { findDrawingController } from "utils/controllers"
import { showError } from "utils/flash"

export default class extends Controller {
  static values = {
    mapId: Number,
    vehicleId: Number,
    hasPlannedPath: { type: Boolean, default: false }
  }
  static targets = ["details", "chevron", "confirmDelete", "webhookUrl", "thresholdInput"]

  toggleDetails() {
    this.detailsTarget.classList.toggle("hidden")
    this.chevronTarget.classList.toggle("rotate-180")
  }

  copyWebhookUrl() {
    const url = this.webhookUrlTarget.value
    navigator.clipboard.writeText(url).then(() => {
      const btn = this.webhookUrlTarget.nextElementSibling
      const original = btn.textContent
      btn.textContent = "Copied!"
      setTimeout(() => btn.textContent = original, 2000)
    })
  }

  toggleActive() {
    turboPatch(`/maps/${this.mapIdValue}/tracked_vehicles/${this.vehicleIdValue}/toggle_active`)
      .then(html => {
        document.documentElement.insertAdjacentHTML("beforeend", html)
      }).catch(err => showError("Failed to toggle active.", err))
  }

  clearPoints() {
    if (!confirm("Clear all tracking history for this vehicle?")) return

    turboDelete(`/maps/${this.mapIdValue}/tracked_vehicles/${this.vehicleIdValue}/clear_points`)
      .then(html => {
        document.documentElement.insertAdjacentHTML("beforeend", html)
      }).catch(err => showError("Failed to clear points.", err))
  }

  saveThreshold() {
    const value = this.thresholdInputTarget.value
    const threshold = value === "" ? null : parseFloat(value)

    turboPatch(`/maps/${this.mapIdValue}/tracked_vehicles/${this.vehicleIdValue}`, {
      tracked_vehicle: { deviation_threshold_meters: threshold }
    })
      .then(html => {
        document.documentElement.insertAdjacentHTML("beforeend", html)
      }).catch(err => showError("Failed to save threshold.", err))
  }

  clearPlannedPath() {
    this.#savePlannedPath(null)
  }

  drawPlannedPath() {
    const drawingCtrl = findDrawingController(this.application)
    if (!drawingCtrl) return

    // Set up a one-time callback to capture the drawn line
    drawingCtrl.plannedPathCallback = (geojson) => {
      this.#savePlannedPath(JSON.stringify(geojson))
      drawingCtrl.plannedPathCallback = null
    }

    drawingCtrl.drawLineForPlannedPath()
  }

  editVehicle() {
    turboGet(`/maps/${this.mapIdValue}/tracked_vehicles/${this.vehicleIdValue}/edit`)
      .then(html => {
        document.documentElement.insertAdjacentHTML("beforeend", html)
      })
  }

  deleteVehicle() {
    this.confirmDeleteTarget.classList.remove("hidden")
  }

  cancelDelete() {
    this.confirmDeleteTarget.classList.add("hidden")
  }

  confirmDeleteVehicle() {
    turboDelete(`/maps/${this.mapIdValue}/tracked_vehicles/${this.vehicleIdValue}`)
      .then(html => {
        document.documentElement.insertAdjacentHTML("beforeend", html)
      }).catch(err => showError("Failed to delete vehicle.", err))
  }

  #savePlannedPath(geojsonString) {
    turboPatch(`/maps/${this.mapIdValue}/tracked_vehicles/${this.vehicleIdValue}/save_planned_path`, {
      planned_path: geojsonString
    })
      .then(html => {
        document.documentElement.insertAdjacentHTML("beforeend", html)
      }).catch(err => showError("Failed to save planned path.", err))
  }
}
