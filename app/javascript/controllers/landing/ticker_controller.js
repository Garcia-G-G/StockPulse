import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["track"]

  connect() {
    this.symbols = [
      { s: "AAPL", p: 258.90, c: 2.13 }, { s: "MSFT", p: 371.98, c: -0.08 },
      { s: "GOOGL", p: 317.52, c: 3.95 }, { s: "NVDA", p: 181.77, c: 2.06 },
      { s: "TSLA", p: 341.98, c: -1.35 }, { s: "AMZN", p: 220.54, c: 3.17 },
      { s: "META", p: 611.02, c: 6.26 }, { s: "BTC", p: 71242, c: 3.71 },
      { s: "ETH", p: 2205, c: 5.05 }, { s: "SOL", p: 83.00, c: 2.47 },
      { s: "AMD", p: 230.43, c: 4.02 }, { s: "NFLX", p: 99.07, c: 0.25 },
      { s: "CRM", p: 177.30, c: -3.09 }, { s: "SPOT", p: 481.17, c: -0.42 }
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
