import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "body", "initialContent"]

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    // Prevent close during active import (polling)
    if (this.dialogTarget.querySelector("[data-import-polling-value='true']")) return

    this.dialogTarget.close()
    this.#resetBody()
  }

  backdropClick(event) {
    if (event.target === this.dialogTarget) {
      this.close()
    }
  }

  preventCancel(event) {
    // Block Escape key during active import
    if (this.dialogTarget.querySelector("[data-import-polling-value='true']")) {
      event.preventDefault()
    }
  }

  #resetBody() {
    if (this.hasInitialContentTarget && this.hasBodyTarget) {
      this.bodyTarget.innerHTML = this.initialContentTarget.innerHTML
    }
  }
}
