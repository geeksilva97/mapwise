import { Controller } from "@hotwired/stimulus"
import { patchJSON } from "utils/http"

export default class extends Controller {
  static values = { mapId: Number, layerId: Number }
  static targets = ["form", "display", "name", "strokeColor", "fillColor", "displayName", "displayDot"]

  toggle() {
    this.formTarget.classList.toggle("hidden")
    this.displayTarget.classList.toggle("hidden")
  }

  deleteLayer(event) {
    event.preventDefault()
    const contentEl = this.displayTarget.querySelector('[data-role="content"]')
    const confirmEl = this.displayTarget.querySelector('[data-role="confirm"]')
    if (contentEl && confirmEl) {
      contentEl.classList.add("hidden")
      confirmEl.classList.remove("hidden")
    }
  }

  cancelDelete(event) {
    event.preventDefault()
    const contentEl = this.displayTarget.querySelector('[data-role="content"]')
    const confirmEl = this.displayTarget.querySelector('[data-role="confirm"]')
    if (contentEl && confirmEl) {
      contentEl.classList.remove("hidden")
      confirmEl.classList.add("hidden")
    }
  }

  confirmDeleteLayer(event) {
    event.preventDefault()
    const drawingEl = document.querySelector("[data-controller='drawing']")
    if (!drawingEl) return
    const drawingCtrl = this.application.getControllerForElementAndIdentifier(drawingEl, "drawing")
    if (drawingCtrl) drawingCtrl.deleteLayerById(this.layerIdValue)
  }

  save(event) {
    event.preventDefault()

    const name = this.nameTarget.value.trim()
    const strokeColor = this.strokeColorTarget.value
    const fillColor = this.fillColorTarget.value

    if (!name) return

    patchJSON(`/maps/${this.mapIdValue}/layers/${this.layerIdValue}`, {
      layer: { name, stroke_color: strokeColor, fill_color: fillColor }
    })
      .then(layer => {
        // Update sidebar display
        this.displayNameTarget.textContent = layer.name
        this.displayDotTarget.style.backgroundColor = layer.fill_color || "#3B82F6"
        this.displayDotTarget.style.borderColor = layer.stroke_color || "#3B82F6"

        // Collapse form
        this.formTarget.classList.add("hidden")
        this.displayTarget.classList.remove("hidden")

        // Update map rendering
        this.#updateDrawingLayers(layer)
      })
      .catch(err => console.error("Failed to update layer:", err))
  }

  #updateDrawingLayers(updatedLayer) {
    const drawingEl = document.querySelector("[data-controller='drawing']")
    if (!drawingEl) return

    const drawingCtrl = this.application.getControllerForElementAndIdentifier(drawingEl, "drawing")
    if (!drawingCtrl) return

    drawingCtrl.layersValue = drawingCtrl.layersValue.map(l =>
      String(l.id) === String(updatedLayer.id)
        ? { ...l, name: updatedLayer.name, stroke_color: updatedLayer.stroke_color, fill_color: updatedLayer.fill_color }
        : l
    )
  }
}
