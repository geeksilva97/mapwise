import { Controller } from "@hotwired/stimulus"
import { findMapController } from "utils/controllers"

export default class extends Controller {
  static values = {
    mode: { type: String, default: "places" },
    markers: { type: Array, default: [] }
  }

  static targets = ["input", "results", "clearButton"]

  connect() {
    this.selectedIndex = -1
    this.debounceTimer = null
    this._onDocumentClick = this.#onDocumentClick.bind(this)
    document.addEventListener("click", this._onDocumentClick)
    this.waitForMap()
  }

  disconnect() {
    if (this._waitTimer) clearTimeout(this._waitTimer)
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
    document.removeEventListener("click", this._onDocumentClick)
  }

  waitForMap() {
    const mapCtrl = findMapController(this.application)
    if (mapCtrl?.map) {
      this.mapController = mapCtrl

      if (this.modeValue === "places") {
        this.#initPlacesAutocomplete()
      }
    } else if (document.getElementById("map-canvas")) {
      this._waitTimer = setTimeout(() => this.waitForMap(), 200)
    }
  }

  onInput() {
    const query = this.inputTarget.value.trim()
    this.#toggleClearButton(query.length > 0)

    if (this.debounceTimer) clearTimeout(this.debounceTimer)

    if (query.length === 0) {
      this.#hideResults()
      return
    }

    this.debounceTimer = setTimeout(() => {
      if (this.modeValue === "places") {
        this.#searchPlaces(query)
      } else {
        this.#searchMarkers(query)
      }
    }, 300)
  }

  onKeydown(event) {
    const items = this.resultsTarget.querySelectorAll("li")
    if (items.length === 0) return

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.selectedIndex = Math.min(this.selectedIndex + 1, items.length - 1)
        this.#highlightItem(items)
        break
      case "ArrowUp":
        event.preventDefault()
        this.selectedIndex = Math.max(this.selectedIndex - 1, 0)
        this.#highlightItem(items)
        break
      case "Enter":
        event.preventDefault()
        if (this.selectedIndex >= 0 && items[this.selectedIndex]) {
          items[this.selectedIndex].click()
        }
        break
      case "Escape":
        this.#hideResults()
        this.inputTarget.blur()
        break
    }
  }

  clear() {
    this.inputTarget.value = ""
    this.#toggleClearButton(false)
    this.#hideResults()
    this.inputTarget.focus()
  }

  // --- Private ---

  #initPlacesAutocomplete() {
    // Use Geocoder as it's part of the core Maps JS API — no extra API needed
    this.geocoder = new google.maps.Geocoder()
  }

  async #searchPlaces(query) {
    if (!this.geocoder || !this.mapController) return

    try {
      const { results } = await this.geocoder.geocode({
        address: query,
        bounds: this.mapController.map.getBounds()
      })

      this.selectedIndex = -1
      this.resultsTarget.innerHTML = ""

      if (!results || results.length === 0) {
        this.#showNoResults("No places found")
        return
      }

      results.slice(0, 8).forEach((result, index) => {
        const li = document.createElement("li")
        li.className = "px-3 py-2 text-sm cursor-pointer hover:bg-blue-50 transition-colors"
        li.dataset.index = index

        const main = document.createElement("span")
        main.className = "font-medium text-gray-800"
        main.textContent = result.formatted_address

        li.appendChild(main)

        li.addEventListener("click", () => {
          if (!this.mapController) return

          if (result.geometry.viewport) {
            this.mapController.map.fitBounds(result.geometry.viewport)
          } else {
            this.mapController.panTo(
              result.geometry.location.lat(),
              result.geometry.location.lng(),
              15
            )
          }

          this.inputTarget.value = result.formatted_address
          this.#hideResults()
        })

        this.resultsTarget.appendChild(li)
      })

      this.#showResults()
    } catch (e) {
      this.#showNoResults("No places found")
    }
  }

  #searchMarkers(query) {
    const lowerQuery = query.toLowerCase()

    const matches = this.markersValue.filter(m => {
      const title = (m.title || "").toLowerCase()
      const description = (m.description || "").toLowerCase()
      return title.includes(lowerQuery) || description.includes(lowerQuery)
    }).slice(0, 20)

    this.selectedIndex = -1
    this.resultsTarget.innerHTML = ""

    if (matches.length === 0) {
      this.#showNoResults("No markers found")
      return
    }

    matches.forEach((m, index) => {
      const li = document.createElement("li")
      li.className = "px-3 py-2 text-sm cursor-pointer hover:bg-blue-50 transition-colors"
      li.dataset.index = index

      const title = document.createElement("span")
      title.className = "font-medium text-gray-800"
      title.textContent = m.title || "Untitled"

      li.appendChild(title)

      if (m.description) {
        const desc = document.createElement("span")
        desc.className = "text-gray-400 ml-1 truncate"
        desc.textContent = m.description
        li.appendChild(desc)
      }

      li.addEventListener("click", () => this.#selectMarker(m))
      this.resultsTarget.appendChild(li)
    })

    this.#showResults()
  }

  #selectMarker(markerData) {
    if (!this.mapController) return

    this.inputTarget.value = markerData.title || ""
    this.#hideResults()

    this.mapController.panTo(markerData.lat, markerData.lng, 15)
    this.mapController.openInfoWindowForMarker(markerData.id)
  }

  #showResults() {
    this.resultsTarget.classList.remove("hidden")
  }

  #hideResults() {
    this.resultsTarget.classList.add("hidden")
    this.selectedIndex = -1
  }

  #showNoResults(message) {
    this.resultsTarget.innerHTML = ""
    const li = document.createElement("li")
    li.className = "px-3 py-2 text-sm text-gray-400"
    li.textContent = message
    this.resultsTarget.appendChild(li)
    this.#showResults()
  }

  #highlightItem(items) {
    items.forEach((item, i) => {
      item.classList.toggle("bg-blue-50", i === this.selectedIndex)
    })
  }

  #toggleClearButton(visible) {
    if (visible) {
      this.clearButtonTarget.classList.remove("hidden")
    } else {
      this.clearButtonTarget.classList.add("hidden")
    }
  }

  #onDocumentClick(event) {
    if (!this.element.contains(event.target)) {
      this.#hideResults()
    }
  }
}
