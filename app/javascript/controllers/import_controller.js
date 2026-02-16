import { Controller } from "@hotwired/stimulus"
import { csrfToken } from "utils/csrf"

export default class extends Controller {
  static values = { mapId: Number, importId: Number, polling: { type: Boolean, default: false } }
  static targets = ["fileInput", "progressBar", "progressText"]

  connect() {
    if (this.pollingValue && this.importIdValue) {
      this.startPolling()
    }
  }

  disconnect() {
    this.stopPolling()
  }

  upload(event) {
    event.preventDefault()
    if (!this.hasFileInputTarget || !this.fileInputTarget.files[0]) return

    const formData = new FormData()
    formData.append("file", this.fileInputTarget.files[0])

    fetch(`/maps/${this.mapIdValue}/imports`, {
      method: "POST",
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "X-CSRF-Token": csrfToken()
      },
      body: formData
    })
      .then(r => {
        if (!r.ok) throw new Error(`Upload failed: ${r.status}`)
        return r.text()
      })
      .then(html => Turbo.renderStreamMessage(html))
      .catch(err => console.error("Upload failed:", err))
  }

  submitMapping(event) {
    event.preventDefault()
    const form = event.target
    const formData = new FormData(form)

    fetch(`/maps/${this.mapIdValue}/imports/${this.importIdValue}`, {
      method: "PATCH",
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "X-CSRF-Token": csrfToken()
      },
      body: new URLSearchParams(formData)
    })
      .then(r => {
        if (!r.ok) throw new Error(`Mapping failed: ${r.status}`)
        return r.text()
      })
      .then(html => Turbo.renderStreamMessage(html))
      .catch(err => console.error("Mapping submission failed:", err))
  }

  startPolling() {
    this.pollInterval = setInterval(() => this.pollProgress(), 2000)
  }

  stopPolling() {
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
      this.pollInterval = null
    }
  }

  pollProgress() {
    if (!this.importIdValue || !this.mapIdValue) return

    fetch(`/maps/${this.mapIdValue}/imports/${this.importIdValue}`, {
      headers: { "Accept": "application/json" }
    })
      .then(r => r.json())
      .then(data => {
        if (this.hasProgressBarTarget) {
          this.progressBarTarget.style.width = `${data.progress}%`
        }
        if (this.hasProgressTextTarget) {
          this.progressTextTarget.textContent = `${data.processed_rows} / ${data.total_rows} rows processed (${data.progress}%)`
        }

        if (data.status === "completed" || data.status === "failed") {
          this.stopPolling()
          // Fetch the turbo stream version to get the completed/failed UI
          fetch(`/maps/${this.mapIdValue}/imports/${this.importIdValue}`, {
            headers: { "Accept": "text/vnd.turbo-stream.html" }
          })
            .then(r => r.text())
            .then(html => Turbo.renderStreamMessage(html))
        }
      })
      .catch(err => console.error("Polling failed:", err))
  }

  cancel() {
    const dialogEl = this.element.closest("[data-controller='import-dialog']")
    if (dialogEl) {
      const dialogCtrl = this.application.getControllerForElementAndIdentifier(dialogEl, "import-dialog")
      if (dialogCtrl) dialogCtrl.close()
    }
  }

  reload() {
    this.#closeDialogAndReload()
  }

  newImport() {
    this.#closeDialogAndReload()
  }

  #closeDialogAndReload() {
    const dialog = this.element.closest("dialog")
    if (dialog) dialog.close()
    location.reload()
  }
}
