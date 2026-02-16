import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "title", "message"]

  open(event) {
    event.preventDefault()
    event.stopPropagation()

    const trigger = event.currentTarget
    this.titleTarget.textContent = trigger.dataset.confirmTitle || "Are you sure?"
    this.messageTarget.textContent = trigger.dataset.confirmMessage || ""
    this._formSelector = trigger.dataset.confirmForm
    this.dialogTarget.showModal()
  }

  confirm() {
    this.dialogTarget.close()
    if (this._formSelector) {
      const form = document.querySelector(this._formSelector)
      if (form) form.requestSubmit()
      this._formSelector = null
    }
  }

  cancel() {
    this.dialogTarget.close()
    this._formSelector = null
  }

  backdropClick(event) {
    if (event.target === this.dialogTarget) {
      this.cancel()
    }
  }
}
