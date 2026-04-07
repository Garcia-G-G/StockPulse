import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.observer = new IntersectionObserver(
      (entries) => entries.forEach(e => { if (e.isIntersecting) e.target.classList.add("vis") }),
      { threshold: 0.12, rootMargin: "0px 0px -30px 0px" }
    )
    this.element.querySelectorAll(".rv").forEach(el => this.observer.observe(el))
  }

  disconnect() {
    this.observer?.disconnect()
  }
}
