import { Controller } from "@hotwired/stimulus"
import { csrfToken } from "utils/csrf"

export default class extends Controller {
  static values = { mapId: Number }
  static targets = ["toggle", "embedSection", "embedCode", "directLink", "status"]

  togglePublic() {
    const isPublic = this.toggleTarget.checked
    this.embedSectionTarget.classList.toggle("hidden", !isPublic)

    fetch(`/maps/${this.mapIdValue}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken()
      },
      body: JSON.stringify({ map: { public: isPublic } })
    })
      .then(r => {
        if (!r.ok) throw new Error(`Failed: ${r.status}`)
        this.#flash(isPublic ? "Map is now public" : "Map is now private")
      })
      .catch(err => {
        console.error("Failed to update visibility:", err)
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
