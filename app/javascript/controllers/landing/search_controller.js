import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "list"]

  connect() {
    this.timeout = null
    this.visible = false
    // Close on click outside
    this.outsideClick = (e) => {
      if (!this.element.contains(e.target)) this.hide()
    }
    document.addEventListener("click", this.outsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this.outsideClick)
    clearTimeout(this.timeout)
  }

  onInput() {
    clearTimeout(this.timeout)
    const q = this.inputTarget.value.trim()
    if (q.length < 1) { this.hide(); return }
    this.timeout = setTimeout(() => this.search(q), 300)
  }

  onFocus() {
    if (this.listTarget.innerHTML.trim()) this.show()
  }

  async search(q) {
    try {
      const resp = await fetch(`/api/search?q=${encodeURIComponent(q)}`)
      if (!resp.ok) return
      const data = await resp.json()
      if (!Array.isArray(data) || data.length === 0) {
        this.listTarget.innerHTML = '<div class="sr-empty">No results found</div>'
        this.show()
        return
      }
      this.listTarget.innerHTML = data.map(r => {
        const up = (r.change || 0) >= 0
        const priceHtml = r.price ? `<div><div class="sr-price">$${r.price.toLocaleString("en", {minimumFractionDigits: 2})}</div><div class="sr-chg" style="color:${up ? "#10B981" : "#F43F5E"}">${up ? "+" : ""}${(r.change || 0).toFixed(2)}%</div></div>` : ""
        return `<a href="/quote/${r.symbol}" class="sr-item"><div><div class="sr-name">${r.name || r.symbol}</div><div class="sr-sym">${r.symbol}${r.type ? " · " + r.type : ""}</div></div>${priceHtml}</a>`
      }).join("")
      this.show()
    } catch {
      // silently fail
    }
  }

  show() {
    this.resultsTarget.style.display = "block"
    this.visible = true
  }

  hide() {
    this.resultsTarget.style.display = "none"
    this.visible = false
  }
}
