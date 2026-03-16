import { Controller } from "@hotwired/stimulus"
import { request, turboPatch, turboDelete } from "utils/http"
import { findMapController } from "utils/controllers"
import { showError } from "utils/flash"

const LAYER_TYPE_MAP = {
  polygon: "polygon",
  linestring: "line",
  circle: "circle",
  rectangle: "rectangle",
  freehand: "freehand"
}

const LAYER_TO_MODE = {
  polygon: "polygon",
  line: "linestring",
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

  static targets = ["toolbar", "layerSync"]

  connect() {
    this.draw = null
    this.activeMode = null
    this.dataLayer = null
    this.dataFeatures = []
    this.editingLayerId = null
    this.editingFeatureId = null
    this.editingOriginalGeometry = null
    this.waitForMap()
  }

  disconnect() {
    if (this._waitTimer) {
      clearTimeout(this._waitTimer)
      this._waitTimer = null
    }
    if (this.draw) {
      this.draw.stop()
      this.draw = null
    }
    if (this.dataLayer) {
      this.dataLayer.setMap(null)
      this.dataLayer = null
    }
  }

  layerSyncTargetConnected(el) {
    this.layersValue = JSON.parse(el.dataset.layers)
    el.remove()
  }

  waitForMap() {
    const mapCtrl = findMapController(this.application)
    if (mapCtrl?.map) {
      this.googleMap = mapCtrl.map
      // Use a separate Data layer so Terra Draw's default data layer doesn't interfere
      this.dataLayer = new google.maps.Data({ map: this.googleMap })
      if (this.readonlyValue) {
        this.renderExistingLayers()
      } else {
        this.initTerraDraw()
      }
    } else if (document.getElementById("map-canvas")) {
      // Element exists but controller/map not ready yet — retry
      this._waitTimer = setTimeout(() => this.waitForMap(), 200)
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
    this.dataFeatures.forEach(({ feature }) => {
      this.dataLayer.remove(feature)
    })
    this.dataFeatures = []

    this.layersValue
      .filter(layer => layer.visible && layer.id !== this.editingLayerId)
      .forEach(layer => {
        try {
          const geojson = typeof layer.geometry_data === "string"
            ? JSON.parse(layer.geometry_data)
            : layer.geometry_data

          if (geojson.type === "Feature") {
            const features = this.dataLayer.addGeoJson(geojson)
            features.forEach(f => {
              f.setProperty("_layerId", layer.id)
              this.dataLayer.overrideStyle(f, {
                strokeColor: layer.stroke_color || "#3B82F6",
                strokeWeight: layer.stroke_width || 2,
                fillColor: layer.fill_color || "#3B82F6",
                fillOpacity: layer.fill_opacity ?? 0.3,
                clickable: false
              })
              this.dataFeatures.push({ feature: f })
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
      btn.classList.toggle("bg-brand-100", isActive)
      btn.classList.toggle("text-brand-700", isActive)
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
    // Ignore finish events for the feature being edited
    if (this.editingFeatureId && id === this.editingFeatureId) return

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

    // Save to server — turbo stream appends sidebar item + syncs layer data
    request(`/maps/${this.mapIdValue}/layers`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "text/vnd.turbo-stream.html" },
      body: JSON.stringify({
        layer: {
          name: autoName,
          layer_type: layerType,
          geometry_data: JSON.stringify(feature)
        }
      })
    })
      .then(resp => resp.text())
      .then(html => Turbo.renderStreamMessage(html))
      .catch(err => showError("Failed to save layer.", err))
  }

  startEditingLayer(layerId) {
    if (!this.draw) return

    // Cancel any in-progress edit first
    if (this.editingLayerId) this.cancelEditingLayer()

    const layer = this.layersValue.find(l => l.id === layerId)
    if (!layer) return

    // Store original geometry for cancel/revert
    this.editingLayerId = layerId
    this.editingOriginalGeometry = layer.geometry_data

    // Remove layer from our Data layer to avoid visual duplicate with Terra Draw
    this.dataFeatures
      .filter(({ feature }) => feature.getProperty("_layerId") === layerId)
      .forEach(({ feature }) => this.dataLayer.remove(feature))
    this.dataFeatures = this.dataFeatures.filter(({ feature }) => feature.getProperty("_layerId") !== layerId)

    // Parse geometry and ensure mode property is set for Terra Draw
    const geojson = typeof layer.geometry_data === "string"
      ? JSON.parse(layer.geometry_data)
      : { ...layer.geometry_data }

    const modeName = LAYER_TO_MODE[layer.layer_type] || "polygon"
    if (geojson.properties) {
      geojson.properties.mode = modeName
    } else {
      geojson.properties = { mode: modeName }
    }

    // Add feature to Terra Draw and switch to select mode
    const results = this.draw.addFeatures([geojson])
    if (!results[0]?.valid) {
      console.warn("Failed to add layer to Terra Draw:", results[0]?.reason)
      this.editingLayerId = null
      this.editingOriginalGeometry = null
      this.renderExistingLayers()
      return
    }
    this.editingFeatureId = results[0].id
    this.setMode("select")
    this.draw.selectFeature(this.editingFeatureId)
  }

  getEditedGeometry() {
    if (!this.draw || !this.editingFeatureId) return null

    const snapshot = this.draw.getSnapshot()
    const feature = snapshot.find(f => f.id === this.editingFeatureId)
    return feature ? JSON.stringify(feature) : null
  }

  finishEditingLayer() {
    if (!this.draw || !this.editingFeatureId) return

    this.draw.removeFeatures([this.editingFeatureId])
    this.editingLayerId = null
    this.editingFeatureId = null
    this.editingOriginalGeometry = null
    this.setMode("render")
    // Caller updates layersValue which triggers re-render on Data layer
  }

  cancelEditingLayer() {
    if (!this.draw || !this.editingFeatureId) return

    this.draw.removeFeatures([this.editingFeatureId])
    this.editingLayerId = null
    this.editingFeatureId = null
    this.editingOriginalGeometry = null
    this.setMode("render")
    this.renderExistingLayers()
  }

  toggleLayerVisibility(event) {
    const layerId = event.currentTarget.dataset.layerId
    if (!layerId) return

    turboPatch(`/maps/${this.mapIdValue}/layers/${layerId}/toggle_visibility`)
      .then(html => {
        // Update local layers data
        this.layersValue = this.layersValue.map(l =>
          String(l.id) === String(layerId) ? { ...l, visible: !l.visible } : l
        )
        // Apply turbo stream response
        document.documentElement.insertAdjacentHTML("beforeend", html)
      })
      .catch(err => showError("Failed to toggle layer.", err))
  }

  deleteLayer(event) {
    const layerId = event.currentTarget.dataset.layerId
    if (!layerId) return
    this.deleteLayerById(layerId)
  }

  deleteLayerById(layerId) {
    turboDelete(`/maps/${this.mapIdValue}/layers/${layerId}`)
      .then(html => {
        // Remove from local layers data
        this.layersValue = this.layersValue.filter(l => String(l.id) !== String(layerId))
        // Apply turbo stream response
        document.documentElement.insertAdjacentHTML("beforeend", html)
      })
      .catch(err => showError("Failed to delete layer.", err))
  }

}
