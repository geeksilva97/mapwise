import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  #debounceTimer = null
  #fadeTimer = null

  connect() {
    // Clear stale indicator if form was replaced after a validation error
    const status = document.getElementById("settings_feedback")
    if (status) status.innerHTML = ""
  }

  disconnect() {
    clearTimeout(this.#debounceTimer)
    clearTimeout(this.#fadeTimer)
  }

  debounceSave(event) {
    const tag = event.target.tagName
    const type = event.target.type
    if (tag === "SELECT" || type === "checkbox") return

    clearTimeout(this.#debounceTimer)
    this.#debounceTimer = setTimeout(() => this.#save(), 500)
  }

  saveNow(event) {
    const tag = event.target.tagName
    const type = event.target.type
    if (tag !== "SELECT" && type !== "checkbox") return

    clearTimeout(this.#debounceTimer)
    this.#save()
  }

  saved() {
    clearTimeout(this.#fadeTimer)
    const status = document.getElementById("settings_feedback")
    if (!status) return

    this.#fadeTimer = setTimeout(() => {
      status.style.transition = "opacity 0.5s ease"
      status.style.opacity = "0"
    }, 2000)
  }

  #save() {
    clearTimeout(this.#fadeTimer)
    const status = document.getElementById("settings_feedback")
    if (status) {
      status.style.transition = ""
      status.style.opacity = "1"
      status.innerHTML = '<span class="text-xs text-gray-400">Saving...</span>'
    }
    this.element.requestSubmit()
  }
}
