import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "message", "deleteForm"]

  open(event) {
    event.preventDefault()
    event.stopPropagation()

    const message = event.currentTarget.dataset.confirmMessage || "Are you sure?"
    this.messageTarget.textContent = message
    this.dialogTarget.showModal()
  }

  confirm() {
    this.dialogTarget.close()
    if (this.hasDeleteFormTarget) {
      this.deleteFormTarget.requestSubmit()
    }
  }

  cancel() {
    this.dialogTarget.close()
  }

  backdropClick(event) {
    if (event.target === this.dialogTarget) {
      this.cancel()
    }
  }
}
