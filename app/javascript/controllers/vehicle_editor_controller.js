import { Controller } from "@hotwired/stimulus"
import { csrfToken } from "utils/csrf"

export default class extends Controller {
  static values = { mapId: Number }
  static targets = ["count"]

  showNewForm() {
    const container = document.getElementById("vehicle_form_container")
    if (!container) return

    const vehicle = { name: "", color: "#3B82F6", deviation_threshold_meters: "" }
    container.innerHTML = this.#buildFormHTML(vehicle)
  }

  hideForm() {
    const container = document.getElementById("vehicle_form_container")
    if (container) container.innerHTML = '<turbo-frame id="vehicle_form"></turbo-frame>'
  }

  #buildFormHTML(vehicle) {
    return `
      <form id="vehicle_form" action="/maps/${this.mapIdValue}/tracked_vehicles" method="post"
            class="bg-gray-50 rounded-lg border border-gray-200 p-3 mb-3 space-y-3">
        <input type="hidden" name="authenticity_token" value="${csrfToken()}">
        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">Name</label>
          <input type="text" name="tracked_vehicle[name]" value="${vehicle.name}"
                 class="block w-full rounded-lg border-gray-300 bg-white text-sm focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20"
                 placeholder="Vehicle name" required>
        </div>
        <div class="grid grid-cols-2 gap-2">
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">Color</label>
            <input type="color" name="tracked_vehicle[color]" value="${vehicle.color}"
                   class="block w-full h-9 rounded-lg border-gray-300 cursor-pointer">
          </div>
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">Deviation (m)</label>
            <input type="number" name="tracked_vehicle[deviation_threshold_meters]"
                   value="${vehicle.deviation_threshold_meters}"
                   class="block w-full rounded-lg border-gray-300 bg-white text-sm focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20"
                   placeholder="e.g. 100" step="1" min="1">
          </div>
        </div>
        <div class="flex gap-2">
          <button type="submit"
                  class="flex-1 rounded-lg px-3 py-2 bg-blue-600 hover:bg-blue-500 text-white text-sm font-medium cursor-pointer">
            Add Vehicle
          </button>
          <button type="button" data-action="click->vehicle-editor#hideForm"
                  class="rounded-lg px-3 py-2 border border-gray-300 hover:bg-gray-50 text-sm font-medium cursor-pointer">
            Cancel
          </button>
        </div>
      </form>
    `
  }
}
