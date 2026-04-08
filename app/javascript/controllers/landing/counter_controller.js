import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["counter"]

  connect() {
    this.observer = new IntersectionObserver(entries => {
      entries.forEach(e => {
        if (e.isIntersecting) {
          const target = parseInt(e.target.dataset.targetValue)
          const suffix = e.target.dataset.suffix || ""
          this.animate(e.target, target, suffix)
          this.observer.unobserve(e.target)
        }
      })
    }, { threshold: 0.5 })
    this.counterTargets.forEach(el => this.observer.observe(el))
  }

  disconnect() { this.observer?.disconnect() }

  animate(el, target, suffix) {
    let cur = 0
    const step = target / 55
    const iv = setInterval(() => {
      cur += step
      if (cur >= target) { cur = target; clearInterval(iv) }
      el.textContent = Math.floor(cur).toLocaleString() + suffix
    }, 28)
  }
}
