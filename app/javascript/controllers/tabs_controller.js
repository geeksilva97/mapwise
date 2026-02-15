import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    const params = new URLSearchParams(window.location.search)
    const tab = params.get("tab")
    if (tab) {
      const index = this.tabTargets.findIndex(t => t.textContent.trim().toLowerCase() === tab.toLowerCase())
      this.showTab(index >= 0 ? index : 0)
    } else {
      this.showTab(0)
    }
  }

  select(event) {
    const index = this.tabTargets.indexOf(event.currentTarget)
    this.showTab(index)
  }

  showTab(index) {
    this.tabTargets.forEach((tab, i) => {
      if (i === index) {
        tab.classList.add("border-blue-600", "text-blue-600")
        tab.classList.remove("border-transparent", "text-gray-500")
      } else {
        tab.classList.remove("border-blue-600", "text-blue-600")
        tab.classList.add("border-transparent", "text-gray-500")
      }
    })

    this.panelTargets.forEach((panel, i) => {
      panel.classList.toggle("hidden", i !== index)
    })
  }
}
