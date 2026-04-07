import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.scrollHandler = () => this.element.classList.toggle("scrolled", window.scrollY > 50)
    window.addEventListener("scroll", this.scrollHandler, { passive: true })
  }

  disconnect() {
    window.removeEventListener("scroll", this.scrollHandler)
  }
}
