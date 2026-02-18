import { Controller } from "@hotwired/stimulus"
import { turboPatch, turboDelete, turboPost, patchJSON } from "utils/http"

export default class extends Controller {
  static values = { id: Number, mapId: Number }
  static targets = ["content", "chevron"]

  toggleCollapse() {
    // Don't collapse while delete confirmation is showing
    const confirmEl = this.element.querySelector('[data-role="confirm"]')
    if (confirmEl && !confirmEl.classList.contains("hidden")) return

    if (!this.hasContentTarget) return
    this.contentTarget.classList.toggle("hidden")
    if (this.hasChevronTarget) {
      this.chevronTarget.classList.toggle("rotate-180")
    }
  }

  toggleVisibility(event) {
    event.preventDefault()
    if (!this.idValue || !this.mapIdValue) return

    turboPatch(`/maps/${this.mapIdValue}/marker_groups/${this.idValue}/toggle_visibility`)
      .then(html => {
        // Update map controller's groups value
        const mapCtrl = this.#mapController()
        if (mapCtrl) {
          mapCtrl.groupsValue = mapCtrl.groupsValue.map(g => {
            if (g.id === this.idValue) {
              return { ...g, visible: !g.visible }
            }
            return g
          })
        }
        // Apply turbo stream to update the eye icon
        Turbo.renderStreamMessage(html)
      })
      .catch(err => console.error("Failed to toggle group visibility:", err))
  }

  pickMarkers(event) {
    event.preventDefault()
    if (!this.idValue || !this.mapIdValue) return

    const mapCtrl = this.#mapController()
    if (!mapCtrl) return

    mapCtrl.enterCircleSelectionMode((markerIds) => {
      if (markerIds.length === 0) return

      patchJSON(`/maps/${this.mapIdValue}/marker_groups/${this.idValue}/assign_markers`, { marker_ids: markerIds })
        .then(() => {
          window.location.reload()
        })
        .catch(err => console.error("Failed to assign markers:", err))
    })
  }

  deleteGroup(event) {
    event.preventDefault()
    if (!this.idValue || !this.mapIdValue) return

    const contentEl = this.element.querySelector('[data-role="content"]')
    const confirmEl = this.element.querySelector('[data-role="confirm"]')
    if (contentEl && confirmEl) {
      contentEl.classList.add("hidden")
      confirmEl.classList.remove("hidden")
    }
  }

  cancelDelete(event) {
    event.preventDefault()
    const contentEl = this.element.querySelector('[data-role="content"]')
    const confirmEl = this.element.querySelector('[data-role="confirm"]')
    if (contentEl && confirmEl) {
      contentEl.classList.remove("hidden")
      confirmEl.classList.add("hidden")
    }
  }

  confirmDeleteGroup(event) {
    event.preventDefault()
    if (!this.idValue || !this.mapIdValue) return

    turboDelete(`/maps/${this.mapIdValue}/marker_groups/${this.idValue}`)
      .then(html => {
        // Remove from map controller's groups value
        const mapCtrl = this.#mapController()
        if (mapCtrl) {
          mapCtrl.groupsValue = mapCtrl.groupsValue.filter(g => g.id !== this.idValue)
          // Clear marker_group_id for affected markers so they become visible again
          mapCtrl.markersValue = mapCtrl.markersValue.map(m => {
            if (m.marker_group_id === this.idValue) {
              return { ...m, marker_group_id: null }
            }
            return m
          })
        }
        // Apply turbo stream to remove the DOM element
        Turbo.renderStreamMessage(html)
      })
      .catch(err => console.error("Failed to delete group:", err))
  }

  showNewForm() {
    const container = document.getElementById("new_group_form_container")
    if (!container || container.querySelector("#group_form")) return

    // Get map ID from the marker-editor controller
    const editorEl = document.querySelector("[data-controller='marker-editor']")
    const mapId = editorEl?.dataset?.markerEditorMapIdValue
    if (!mapId) return

    container.innerHTML = `
      <div id="group_form" class="border rounded-lg p-3 mb-3 bg-gray-50">
        <form data-action="submit->group#submitNewForm" class="space-y-2">
          <div>
            <label class="block text-xs font-medium text-gray-700">Name</label>
            <input type="text" name="name" placeholder="Group name" required
                   class="block w-full shadow-sm rounded-md border border-gray-300 focus:outline-blue-600 px-3 py-1.5 mt-1 text-sm">
          </div>
          <div>
            <label class="block text-xs font-medium text-gray-700">Color</label>
            <input type="color" name="color" value="#6B7280"
                   class="h-8 w-full rounded-md border border-gray-300 cursor-pointer mt-1">
          </div>
          <div class="flex gap-2">
            <button type="submit"
                    class="rounded-md px-3 py-1.5 bg-blue-600 hover:bg-blue-500 text-white text-sm font-medium cursor-pointer">
              Create Group
            </button>
            <button type="button" data-action="click->group#cancelForm"
                    class="rounded-md px-3 py-1.5 border border-gray-300 hover:bg-gray-50 text-sm font-medium cursor-pointer">
              Cancel
            </button>
          </div>
        </form>
      </div>
    `
  }

  cancelForm() {
    const form = document.getElementById("group_form")
    if (form) form.remove()
  }

  submitNewForm(event) {
    event.preventDefault()
    const form = event.target
    const formData = new FormData(form)

    const editorEl = document.querySelector("[data-controller='marker-editor']")
    const mapId = editorEl?.dataset?.markerEditorMapIdValue
    if (!mapId) return

    turboPost(`/maps/${mapId}/marker_groups`, new URLSearchParams({
      "marker_group[name]": formData.get("name"),
      "marker_group[color]": formData.get("color")
    }))
      .then(html => {
        Turbo.renderStreamMessage(html)
        // Update map controller's groups value
        const mapCtrl = this.#mapController()
        if (mapCtrl) {
          // Reload page data for groups would be complex, so we just let Turbo handle the DOM
          // The groups data attribute doesn't need immediate update since visibility is true by default
        }
      })
      .catch(err => console.error("Failed to create group:", err))
  }

  #mapController() {
    const mapEl = document.getElementById("map-canvas")
    return this.application.getControllerForElementAndIdentifier(mapEl, "map")
  }
}
