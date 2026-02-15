import { Controller } from "@hotwired/stimulus"
import { csrfToken } from "utils/csrf"

export default class extends Controller {
  static values = {
    mapId: Number,
    vehicleId: Number,
    hasPlannedPath: { type: Boolean, default: false }
  }
  static targets = ["details", "chevron", "confirmDelete", "webhookUrl"]

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
    fetch(`/maps/${this.mapIdValue}/tracked_vehicles/${this.vehicleIdValue}/toggle_active`, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": csrfToken(),
        "Accept": "text/vnd.turbo-stream.html"
      }
    }).then(resp => {
      if (!resp.ok) throw new Error("Failed to toggle active")
      return resp.text()
    }).then(html => {
      document.documentElement.insertAdjacentHTML("beforeend", html)
    }).catch(err => console.error("Failed to toggle active:", err))
  }

  clearPoints() {
    if (!confirm("Clear all tracking history for this vehicle?")) return

    fetch(`/maps/${this.mapIdValue}/tracked_vehicles/${this.vehicleIdValue}/clear_points`, {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": csrfToken(),
        "Accept": "text/vnd.turbo-stream.html"
      }
    }).then(resp => {
      if (!resp.ok) throw new Error("Failed to clear points")
      return resp.text()
    }).then(html => {
      document.documentElement.insertAdjacentHTML("beforeend", html)
    }).catch(err => console.error("Failed to clear points:", err))
  }

  drawPlannedPath() {
    const drawingEl = document.querySelector("[data-controller~='drawing']")
    if (!drawingEl) return

    const drawingCtrl = this.application.getControllerForElementAndIdentifier(drawingEl, "drawing")
    if (!drawingCtrl) return

    // Set up a one-time callback to capture the drawn line
    drawingCtrl.plannedPathCallback = (geojson) => {
      this.#savePlannedPath(JSON.stringify(geojson))
      drawingCtrl.plannedPathCallback = null
    }

    drawingCtrl.drawLineForPlannedPath()
  }

  editVehicle() {
    // Load the edit form via Turbo
    fetch(`/maps/${this.mapIdValue}/tracked_vehicles/${this.vehicleIdValue}/edit`, {
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "X-CSRF-Token": csrfToken()
      }
    }).then(resp => resp.text())
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
    fetch(`/maps/${this.mapIdValue}/tracked_vehicles/${this.vehicleIdValue}`, {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": csrfToken(),
        "Accept": "text/vnd.turbo-stream.html"
      }
    }).then(resp => {
      if (!resp.ok) throw new Error("Failed to delete vehicle")
      return resp.text()
    }).then(html => {
      document.documentElement.insertAdjacentHTML("beforeend", html)
    }).catch(err => console.error("Failed to delete vehicle:", err))
  }

  #savePlannedPath(geojsonString) {
    fetch(`/maps/${this.mapIdValue}/tracked_vehicles/${this.vehicleIdValue}/save_planned_path`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken(),
        "Accept": "text/vnd.turbo-stream.html"
      },
      body: JSON.stringify({ planned_path: geojsonString })
    }).then(resp => {
      if (!resp.ok) throw new Error("Failed to save planned path")
      return resp.text()
    }).then(html => {
      document.documentElement.insertAdjacentHTML("beforeend", html)
    }).catch(err => console.error("Failed to save planned path:", err))
  }
}
