import { Controller } from "@hotwired/stimulus"
import { patchJSON } from "utils/http"

export default class extends Controller {
  static values = { mapId: Number, layerId: Number }
  static targets = ["form", "display", "name", "strokeColor", "fillColor", "displayName", "displayDot"]

  toggle() {
    const isOpening = this.formTarget.classList.contains("hidden")
    this.formTarget.classList.toggle("hidden")
    this.displayTarget.classList.toggle("hidden")

    const drawingCtrl = this.#drawingController()
    if (!drawingCtrl) return

    if (isOpening) {
      drawingCtrl.startEditingLayer(this.layerIdValue)
    } else {
      drawingCtrl.cancelEditingLayer()
    }
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

    // Capture edited geometry before finishing
    const drawingCtrl = this.#drawingController()
    const editedGeometry = drawingCtrl?.getEditedGeometry()

    const layerParams = { name, stroke_color: strokeColor, fill_color: fillColor }
    if (editedGeometry) layerParams.geometry_data = editedGeometry

    patchJSON(`/maps/${this.mapIdValue}/layers/${this.layerIdValue}`, {
      layer: layerParams
    })
      .then(layer => {
        // Update sidebar display
        this.displayNameTarget.textContent = layer.name
        this.displayDotTarget.style.backgroundColor = layer.fill_color || "#3B82F6"
        this.displayDotTarget.style.borderColor = layer.stroke_color || "#3B82F6"

        // Collapse form
        this.formTarget.classList.add("hidden")
        this.displayTarget.classList.remove("hidden")

        // Finish editing in Terra Draw, then update map rendering
        if (drawingCtrl) drawingCtrl.finishEditingLayer()
        this.#updateDrawingLayers(layer)
      })
      .catch(err => console.error("Failed to update layer:", err))
  }

  #updateDrawingLayers(updatedLayer) {
    const drawingCtrl = this.#drawingController()
    if (!drawingCtrl) return

    drawingCtrl.layersValue = drawingCtrl.layersValue.map(l =>
      String(l.id) === String(updatedLayer.id)
        ? { ...l, name: updatedLayer.name, stroke_color: updatedLayer.stroke_color, fill_color: updatedLayer.fill_color, geometry_data: updatedLayer.geometry_data }
        : l
    )
  }

  #drawingController() {
    const drawingEl = document.querySelector("[data-controller='drawing']")
    if (!drawingEl) return null
    return this.application.getControllerForElementAndIdentifier(drawingEl, "drawing")
  }
}
