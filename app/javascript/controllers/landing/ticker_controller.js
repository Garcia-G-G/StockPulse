import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["track"]

  connect() {
    // Realistic fallback prices (updated 2026-04-07)
    this.symbols = [
      { s: "AAPL", p: 257.58, c: 1.61 }, { s: "MSFT", p: 371.98, c: -0.08 },
      { s: "GOOGL", p: 317.52, c: 3.95 }, { s: "NVDA", p: 181.77, c: 2.06 },
      { s: "TSLA", p: 341.98, c: -1.35 }, { s: "AMZN", p: 220.54, c: 0.56 },
      { s: "META", p: 611.02, c: 1.67 }, { s: "BTC", p: 71241.59, c: 0.89 },
      { s: "ETH", p: 2204.78, c: -0.34 }, { s: "SOL", p: 83.00, c: 3.21 },
      { s: "AMD", p: 230.43, c: 1.45 }, { s: "NFLX", p: 99.07, c: -0.23 },
      { s: "CRM", p: 177.30, c: 0.78 }, { s: "SPOT", p: 481.17, c: 1.89 }
    ]
    this.render()
    this.fetchLivePrices()
    this.interval = setInterval(() => this.fluctuate(), 3000)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  async fetchLivePrices() {
    try {
      const resp = await fetch("/api/prices")
      if (!resp.ok) return
      const data = await resp.json()
      if (!Array.isArray(data) || data.length === 0) return
      // Merge live data into existing symbols
      data.forEach(live => {
        const existing = this.symbols.find(s => s.s === live.s)
        if (existing) {
          existing.p = live.p
          existing.c = live.c
        } else {
          this.symbols.push(live)
        }
      })
      // Re-render with live data and update DOM
      this.render()
    } catch {
      // Keep fallback data
    }
  }

  render() {
    let html = ""
    for (let r = 0; r < 3; r++) {
      this.symbols.forEach(s => {
        const up = s.c >= 0
        const ps = s.p >= 1000 ? s.p.toLocaleString("en", { maximumFractionDigits: 0 }) : s.p.toFixed(s.p < 10 ? 4 : 2)
        html += `<div class="ticker-item"><span class="ticker-sym">${s.s}</span><span class="ticker-price">${ps}</span><span class="ticker-chg ${up ? "up" : "dn"}">${up ? "+" : ""}${s.c.toFixed(2)}%</span></div>`
      })
    }
    this.trackTarget.innerHTML = html
  }

  fluctuate() {
    this.symbols.forEach(s => {
      s.p *= (1 + (Math.random() - 0.48) * 0.002)
      s.c += (Math.random() - 0.5) * 0.1
      s.c = Math.max(-5, Math.min(5, s.c))
    })
    // Update DOM text without full re-render (preserves CSS scroll position)
    const items = this.trackTarget.querySelectorAll(".ticker-item")
    items.forEach(item => {
      const sym = item.querySelector(".ticker-sym").textContent
      const s = this.symbols.find(x => x.s === sym)
      if (!s) return
      const ps = s.p >= 1000 ? s.p.toLocaleString("en", { maximumFractionDigits: 0 }) : s.p.toFixed(s.p < 10 ? 4 : 2)
      item.querySelector(".ticker-price").textContent = ps
      const chgEl = item.querySelector(".ticker-chg")
      chgEl.textContent = `${s.c >= 0 ? "+" : ""}${s.c.toFixed(2)}%`
      chgEl.className = `ticker-chg ${s.c >= 0 ? "up" : "dn"}`
    })
  }
}
