import { Controller } from "@hotwired/stimulus"

// Counts from 0 to `target` when scrolled into view.
// Usage:
//   data-controller="landing--counter"
//   data-landing--counter-target-value="8400"
//   data-landing--counter-suffix-value="+"
export default class extends Controller {
  static values = {
    target: { type: Number, default: 0 },
    suffix: { type: String, default: "" },
    duration: { type: Number, default: 1600 }
  }

  connect() {
    this.element.textContent = "0" + this.suffixValue
    this.observer = new IntersectionObserver(entries => {
      entries.forEach(e => {
        if (e.isIntersecting) {
          this.animate()
          this.observer.disconnect()
        }
      })
    }, { threshold: 0.5 })
    this.observer.observe(this.element)
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
    if (this.intervalId) clearInterval(this.intervalId)
  }

  animate() {
    const target = this.targetValue
    const suffix = this.suffixValue
    const steps = 55
    const stepSize = target / steps
    const tick = this.durationValue / steps
    let cur = 0
    this.intervalId = setInterval(() => {
      cur += stepSize
      if (cur >= target) {
        cur = target
        clearInterval(this.intervalId)
        this.intervalId = null
      }
      this.element.textContent = Math.floor(cur).toLocaleString() + suffix
    }, tick)
  }
}
