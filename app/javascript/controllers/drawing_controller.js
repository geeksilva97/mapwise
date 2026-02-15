import { Controller } from "@hotwired/stimulus"
import { csrfToken } from "utils/csrf"

const LAYER_TYPE_MAP = {
  polygon: "polygon",
  linestring: "line",
  circle: "circle",
  rectangle: "rectangle",
  freehand: "freehand"
}

export default class extends Controller {
  static values = {
    mapId: Number,
    readonly: { type: Boolean, default: true },
    layers: { type: Array, default: [] }
  }

  static targets = ["toolbar"]

  connect() {
    this.draw = null
    this.activeMode = null
    this.dataFeatures = []
    this.waitForMap()
  }

  disconnect() {
    if (this.draw) {
      this.draw.stop()
      this.draw = null
    }
  }

  waitForMap() {
    const mapEl = document.getElementById("map-canvas")
    if (!mapEl) return

    const mapCtrl = this.application.getControllerForElementAndIdentifier(mapEl, "map")
    if (mapCtrl?.map) {
      this.googleMap = mapCtrl.map
      if (this.readonlyValue) {
        this.renderExistingLayers()
      } else {
        this.initTerraDraw()
      }
    } else {
      // Retry until map is ready
      setTimeout(() => this.waitForMap(), 200)
    }
  }

  async initTerraDraw() {
    try {
      const { TerraDraw, TerraDrawRenderMode, TerraDrawPolygonMode,
              TerraDrawLineStringMode, TerraDrawCircleMode,
              TerraDrawRectangleMode, TerraDrawFreehandMode,
              TerraDrawSelectMode } = await import("terra-draw")

      const { TerraDrawGoogleMapsAdapter } = await import("terra-draw-google-maps-adapter")

      const adapter = new TerraDrawGoogleMapsAdapter({
        lib: google.maps,
        map: this.googleMap,
        coordinatePrecision: 9
      })

      const modes = [new TerraDrawRenderMode({ modeName: "render" })]

      if (!this.readonlyValue) {
        modes.push(
          new TerraDrawPolygonMode(),
          new TerraDrawLineStringMode(),
          new TerraDrawCircleMode(),
          new TerraDrawRectangleMode(),
          new TerraDrawFreehandMode(),
          new TerraDrawSelectMode({
            flags: {
              polygon: { feature: { draggable: true, coordinates: { midpoints: true, draggable: true, deletable: true } } },
              linestring: { feature: { draggable: true, coordinates: { midpoints: true, draggable: true, deletable: true } } },
              circle: { feature: { draggable: true, coordinates: { draggable: true } } },
              rectangle: { feature: { draggable: true, coordinates: { draggable: true } } },
              freehand: { feature: { draggable: true, coordinates: { midpoints: false, draggable: false, deletable: false } } }
            }
          })
        )
      }

      this.draw = new TerraDraw({
        adapter,
        modes
      })

      this.draw.start()
      this.draw.setMode("render")

      if (!this.readonlyValue) {
        this.draw.on("finish", (id) => this.handleFinish(id))
      }

      this.renderExistingLayers()
    } catch (e) {
      console.warn("Terra Draw failed to initialize:", e)
    }
  }

  renderExistingLayers() {
    // Clear any previously rendered data features
    this.dataFeatures.forEach(feature => {
      const gMap = this.googleMap
      const existing = gMap.data.getFeatureById(feature.id)
      if (existing) gMap.data.remove(existing)
    })
    this.dataFeatures = []

    this.layersValue
      .filter(layer => layer.visible)
      .forEach(layer => {
        try {
          const geojson = typeof layer.geometry_data === "string"
            ? JSON.parse(layer.geometry_data)
            : layer.geometry_data

          if (geojson.type === "Feature") {
            const features = this.googleMap.data.addGeoJson(geojson)
            features.forEach(f => {
              f.setProperty("_layerId", layer.id)
              this.googleMap.data.overrideStyle(f, {
                strokeColor: layer.stroke_color || "#3B82F6",
                strokeWeight: layer.stroke_width || 2,
                fillColor: layer.fill_color || "#3B82F6",
                fillOpacity: layer.fill_opacity ?? 0.3,
                clickable: false
              })
              this.dataFeatures.push({ id: f.getId(), feature: f })
            })
          }
        } catch (e) {
          console.warn("Failed to render layer:", layer.id, e)
        }
      })
  }

  layersValueChanged() {
    if (this.googleMap) {
      this.renderExistingLayers()
    }
  }

  // Drawing toolbar actions
  drawPolygon() {
    this.setMode("polygon")
  }

  drawLine() {
    this.setMode("linestring")
  }

  drawCircle() {
    this.setMode("circle")
  }

  drawRectangle() {
    this.setMode("rectangle")
  }

  drawFreehand() {
    this.setMode("freehand")
  }

  selectMode() {
    this.setMode("select")
  }

  cancelDrawing() {
    this.setMode("render")
  }

  setMode(mode) {
    if (!this.draw) return

    this.activeMode = mode
    this.draw.setMode(mode)
    this.updateToolbarState()
  }

  updateToolbarState() {
    if (!this.hasToolbarTarget) return

    this.toolbarTarget.querySelectorAll("[data-mode]").forEach(btn => {
      const isActive = btn.dataset.mode === this.activeMode
      btn.classList.toggle("bg-blue-100", isActive)
      btn.classList.toggle("text-blue-700", isActive)
      btn.classList.toggle("ring-1", isActive)
      btn.classList.toggle("ring-blue-300", isActive)
    })
  }

  // Callback-based LineString mode for planned path drawing
  drawLineForPlannedPath() {
    if (!this.draw) return

    this.plannedPathMode = true
    this.setMode("linestring")
  }

  handleFinish(id) {
    const snapshot = this.draw.getSnapshot()
    const feature = snapshot.find(f => f.id === id)
    if (!feature) return

    // If in planned path mode, invoke the callback instead of saving as layer
    if (this.plannedPathMode && this.plannedPathCallback) {
      this.draw.removeFeatures([id])
      this.draw.setMode("render")
      this.activeMode = "render"
      this.plannedPathMode = false
      this.updateToolbarState()
      this.plannedPathCallback(feature)
      return
    }

    const geometryType = feature.geometry.type.toLowerCase()
    const layerType = LAYER_TYPE_MAP[geometryType] || "polygon"
    const autoName = `${layerType.charAt(0).toUpperCase() + layerType.slice(1)} ${this.layersValue.length + 1}`

    // Remove from Terra Draw canvas (we'll render via Google Maps Data layer)
    this.draw.removeFeatures([id])
    this.draw.setMode("render")
    this.activeMode = "render"
    this.updateToolbarState()

    // Save to server
    fetch(`/maps/${this.mapIdValue}/layers`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken(),
        "Accept": "application/json"
      },
      body: JSON.stringify({
        layer: {
          name: autoName,
          layer_type: layerType,
          geometry_data: JSON.stringify(feature)
        }
      })
    })
      .then(resp => {
        if (!resp.ok) throw new Error("Failed to save layer")
        return resp.json()
      })
      .then(layer => {
        // Add to local layers array to trigger re-render on map
        this.layersValue = [...this.layersValue, layer]
        // Add to sidebar list
        this.#appendLayerToSidebar(layer)
      })
      .catch(err => console.error("Failed to save layer:", err))
  }

  toggleLayerVisibility(event) {
    const layerId = event.currentTarget.dataset.layerId
    if (!layerId) return

    fetch(`/maps/${this.mapIdValue}/layers/${layerId}/toggle_visibility`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken(),
        "Accept": "text/vnd.turbo-stream.html"
      }
    })
      .then(resp => {
        if (!resp.ok) throw new Error("Failed to toggle visibility")
        return resp.text()
      })
      .then(html => {
        // Update local layers data
        this.layersValue = this.layersValue.map(l =>
          String(l.id) === String(layerId) ? { ...l, visible: !l.visible } : l
        )
        // Apply turbo stream response
        document.documentElement.insertAdjacentHTML("beforeend", html)
      })
      .catch(err => console.error("Failed to toggle layer:", err))
  }

  deleteLayer(event) {
    const layerId = event.currentTarget.dataset.layerId
    if (!layerId) return
    this.deleteLayerById(layerId)
  }

  deleteLayerById(layerId) {
    fetch(`/maps/${this.mapIdValue}/layers/${layerId}`, {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": csrfToken(),
        "Accept": "text/vnd.turbo-stream.html"
      }
    })
      .then(resp => {
        if (!resp.ok) throw new Error("Failed to delete layer")
        return resp.text()
      })
      .then(html => {
        // Remove from local layers data
        this.layersValue = this.layersValue.filter(l => String(l.id) !== String(layerId))
        // Apply turbo stream response
        document.documentElement.insertAdjacentHTML("beforeend", html)
      })
      .catch(err => console.error("Failed to delete layer:", err))
  }

  #appendLayerToSidebar(layer) {
    const list = document.getElementById("layers_list")
    if (!list) return

    const empty = document.getElementById("layers_empty")
    if (empty) empty.remove()

    // Outer wrapper with layer-item controller
    const wrapper = document.createElement("div")
    wrapper.id = `layer_${layer.id}`
    wrapper.dataset.controller = "layer-item"
    wrapper.dataset.layerItemMapIdValue = this.mapIdValue
    wrapper.dataset.layerItemLayerIdValue = layer.id

    // Display target
    const display = document.createElement("div")
    display.dataset.layerItemTarget = "display"

    // Content row
    const content = document.createElement("div")
    content.dataset.role = "content"
    content.className = "flex items-center justify-between px-3 py-2 rounded-md hover:bg-gray-50 group"

    const left = document.createElement("div")
    left.className = "flex items-center gap-2 min-w-0"

    const dot = document.createElement("span")
    dot.className = "w-3 h-3 rounded border shrink-0"
    dot.style.backgroundColor = layer.fill_color || "#3B82F6"
    dot.style.borderColor = layer.stroke_color || "#3B82F6"

    const name = document.createElement("span")
    name.className = "text-sm font-medium truncate"
    name.textContent = layer.name

    const type = document.createElement("span")
    type.className = "text-xs text-gray-400 capitalize"
    type.textContent = layer.layer_type

    left.appendChild(dot)
    left.appendChild(name)
    left.appendChild(type)

    const right = document.createElement("div")
    right.className = "flex items-center gap-1.5 shrink-0 opacity-0 group-hover:opacity-100"

    const visBtn = document.createElement("button")
    visBtn.type = "button"
    visBtn.dataset.action = "click->marker-editor#toggleLayerVisibility"
    visBtn.dataset.layerId = layer.id
    visBtn.className = "p-1 rounded hover:bg-gray-200 transition-colors"
    visBtn.title = "Hide"
    visBtn.innerHTML = `<svg class="h-3.5 w-3.5 text-gray-500" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z" /><path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /></svg>`

    const delBtn = document.createElement("button")
    delBtn.type = "button"
    delBtn.dataset.action = "click->layer-item#deleteLayer"
    delBtn.className = "p-1 rounded hover:bg-red-100 transition-colors"
    delBtn.title = "Delete layer"
    delBtn.innerHTML = `<svg class="h-3.5 w-3.5 text-gray-400 hover:text-red-600" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" /></svg>`

    right.appendChild(visBtn)
    right.appendChild(delBtn)

    content.appendChild(left)
    content.appendChild(right)

    // Confirm bar
    const confirm = document.createElement("div")
    confirm.dataset.role = "confirm"
    confirm.className = "hidden flex items-center justify-between px-3 py-2 bg-red-50 rounded-md"

    const confirmText = document.createElement("span")
    confirmText.className = "text-sm text-red-700 font-medium"
    confirmText.textContent = "Delete layer?"

    const confirmButtons = document.createElement("div")
    confirmButtons.className = "flex gap-2"

    const cancelBtn = document.createElement("button")
    cancelBtn.dataset.action = "click->layer-item#cancelDelete"
    cancelBtn.className = "text-xs font-medium text-gray-600 hover:text-gray-800 cursor-pointer"
    cancelBtn.textContent = "Cancel"

    const deleteBtn = document.createElement("button")
    deleteBtn.dataset.action = "click->layer-item#confirmDeleteLayer"
    deleteBtn.className = "text-xs font-medium text-white bg-red-600 hover:bg-red-500 rounded-md px-2.5 py-1 cursor-pointer"
    deleteBtn.textContent = "Delete"

    confirmButtons.appendChild(cancelBtn)
    confirmButtons.appendChild(deleteBtn)
    confirm.appendChild(confirmText)
    confirm.appendChild(confirmButtons)

    display.appendChild(content)
    display.appendChild(confirm)
    wrapper.appendChild(display)
    list.appendChild(wrapper)
  }
}
