import { Controller } from "@hotwired/stimulus"
import { turboPatch, turboDelete, turboPost, patchJSON } from "utils/http"
import { findMapController } from "utils/controllers"
import { showError } from "utils/flash"

export default class extends Controller {
  static values = { id: Number, mapId: Number, color: String }
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
      .catch(err => showError("Failed to toggle group visibility.", err))
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
          const groupColor = this.colorValue || "#6B7280"

          // Update map markers data
          const markerIdSet = new Set(markerIds)
          mapCtrl.markersValue = mapCtrl.markersValue.map(m =>
            markerIdSet.has(m.id)
              ? { ...m, marker_group_id: this.idValue, color: groupColor }
              : m
          )

          const groupContent = this.element.querySelector('[data-group-target="content"]')
          if (!groupContent) return

          // Remove "No markers" placeholder
          const placeholder = groupContent.querySelector('p.text-xs.text-gray-400')
          if (placeholder) placeholder.remove()

          // Track source groups for count updates
          const affectedGroups = new Set()

          markerIds.forEach(id => {
            const item = document.getElementById(`marker_${id}`)
            if (!item) return

            // Track source group before moving
            const sourceGroup = item.closest('[id^="group_"]')
            if (sourceGroup && sourceGroup !== this.element) affectedGroups.add(sourceGroup)

            // Update color dot
            const dot = item.querySelector('.w-3.h-3.rounded-full')
            if (dot) dot.style.backgroundColor = groupColor

            // Add "Ungroup" link if not present
            const actions = item.querySelector('.flex.items-center.gap-2.shrink-0')
            if (actions && !actions.querySelector('[data-action*="ungroupMarker"]')) {
              const ungroupLink = document.createElement("a")
              ungroupLink.href = "#"
              ungroupLink.dataset.action = "click->marker-editor#ungroupMarker"
              ungroupLink.dataset.markerEditorIdParam = id
              ungroupLink.className = "text-gray-500 hover:text-gray-700 text-xs font-medium cursor-pointer"
              ungroupLink.title = "Remove from group"
              ungroupLink.textContent = "Ungroup"
              actions.insertBefore(ungroupLink, actions.firstChild)
            }

            groupContent.appendChild(item)
          })

          // Update target group count
          this.#updateGroupCount(this.element)

          // Update source group counts
          affectedGroups.forEach(groupEl => this.#updateGroupCount(groupEl))
        })
        .catch(err => showError("Failed to assign markers.", err))
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
        // Move marker items back to ungrouped list before removing the group DOM
        const markersList = document.getElementById("markers_list")
        if (markersList) {
          const groupContent = this.element.querySelector('[data-group-target="content"]')
          if (groupContent) {
            groupContent.querySelectorAll('[id^="marker_"]').forEach(item => {
              // Remove the "Ungroup" link since markers are now ungrouped
              const ungroupLink = item.querySelector('[data-action*="ungroupMarker"]')
              if (ungroupLink) ungroupLink.remove()
              markersList.appendChild(item)
            })
          }
        }

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
        // Apply turbo stream to remove the group DOM element
        Turbo.renderStreamMessage(html)
      })
      .catch(err => showError("Failed to delete group.", err))
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
                   class="block w-full shadow-sm rounded-md border border-gray-300 focus:outline-brand-600 px-3 py-1.5 mt-1 text-sm">
          </div>
          <div>
            <label class="block text-xs font-medium text-gray-700">Color</label>
            <input type="color" name="color" value="#6B7280"
                   class="h-8 w-full rounded-md border border-gray-300 cursor-pointer mt-1">
          </div>
          <div class="flex gap-2">
            <button type="submit"
                    class="rounded-md px-3 py-1.5 bg-brand-600 hover:bg-brand-500 text-white text-sm font-medium cursor-pointer">
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
      })
      .catch(err => showError("Failed to create group.", err))
  }

  #mapController() {
    return findMapController(this.application)
  }

  #updateGroupCount(groupEl) {
    const content = groupEl.querySelector('[data-group-target="content"]')
    const countSpan = groupEl.querySelector('span.text-xs.text-gray-400')
    if (countSpan && content) {
      const count = content.querySelectorAll('[id^="marker_"]').length
      countSpan.textContent = `(${count})`
    }
  }
}
