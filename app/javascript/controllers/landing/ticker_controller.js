import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["track"]

  connect() {
    this.symbols = [
      { s: "AAPL", p: 198.45, c: 1.23 }, { s: "MSFT", p: 445.12, c: -0.45 },
      { s: "GOOGL", p: 178.90, c: 0.87 }, { s: "NVDA", p: 924.56, c: 2.34 },
      { s: "TSLA", p: 178.30, c: -1.12 }, { s: "AMZN", p: 192.78, c: 0.56 },
      { s: "META", p: 512.34, c: 1.67 }, { s: "BTC", p: 71245, c: 0.89 },
      { s: "ETH", p: 3567, c: -0.34 }, { s: "EUR/USD", p: 1.0867, c: 0.12 },
      { s: "SOL", p: 187.45, c: 3.21 }, { s: "AMD", p: 178.90, c: 1.45 },
      { s: "NFLX", p: 634.12, c: -0.23 }, { s: "CRM", p: 312.45, c: 0.78 },
      { s: "SPOT", p: 298.67, c: 1.89 }
    ]
    this.render()
    this.interval = setInterval(() => this.fluctuate(), 3000)
  }

  disconnect() {
    clearInterval(this.interval)
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
