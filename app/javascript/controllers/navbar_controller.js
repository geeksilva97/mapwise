import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "dropdown"]

  connect() {
    this.closeDropdownBound = this.closeDropdown.bind(this)
    document.addEventListener("click", this.closeDropdownBound)
  }

  disconnect() {
    document.removeEventListener("click", this.closeDropdownBound)
  }

  toggle() {
    this.menuTarget.classList.toggle("hidden")
  }

  toggleDropdown(event) {
    event.stopPropagation()
    this.dropdownTarget.classList.toggle("hidden")
  }

  closeDropdown(event) {
    if (this.hasDropdownTarget && !this.dropdownTarget.classList.contains("hidden")) {
      this.dropdownTarget.classList.add("hidden")
    }
  }
}
