import { Controller } from "@hotwired/stimulus"
import { request } from "utils/http"
import { showError } from "utils/flash"

export default class extends Controller {
  static values = { mapId: Number }
  static targets = ["toggle", "embedSection", "embedCode", "directLink", "status"]

  disconnect() {
    clearTimeout(this._flashTimeout)
  }

  togglePublic() {
    const isPublic = this.toggleTarget.checked
    this.embedSectionTarget.classList.toggle("hidden", !isPublic)

    request(`/maps/${this.mapIdValue}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ map: { public: isPublic } })
    })
      .then(() => {
        this.#flash(isPublic ? "Map is now public" : "Map is now private")
      })
      .catch(err => {
        showError("Failed to update map visibility.", err)
        this.toggleTarget.checked = !isPublic
        this.embedSectionTarget.classList.toggle("hidden", isPublic)
      })
  }

  copyEmbed() {
    this.#copyToClipboard(this.embedCodeTarget.value, this.embedCodeTarget)
  }

  copyLink() {
    this.#copyToClipboard(this.directLinkTarget.value, this.directLinkTarget)
  }

  // --- Private ---

  #copyToClipboard(text, input) {
    navigator.clipboard.writeText(text).then(() => {
      this.#flash("Copied!")
      input.select()
    })
  }

  #flash(message) {
    this.statusTarget.textContent = message
    this.statusTarget.classList.remove("hidden")
    clearTimeout(this._flashTimeout)
    this._flashTimeout = setTimeout(() => {
      this.statusTarget.classList.add("hidden")
    }, 2000)
  }
}
