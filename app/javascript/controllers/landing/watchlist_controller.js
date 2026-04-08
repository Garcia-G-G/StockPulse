import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list"]

  connect() {
    this.stocks = [
      { s: "AAPL", n: "Apple", p: 198.45, c: 1.23, ico: "🍎" },
      { s: "NVDA", n: "NVIDIA", p: 924.56, c: 2.34, ico: "🟢" },
      { s: "TSLA", n: "Tesla", p: 178.30, c: -1.12, ico: "⚡" },
      { s: "MSFT", n: "Microsoft", p: 445.12, c: -0.45, ico: "🔷" },
      { s: "GOOGL", n: "Alphabet", p: 178.90, c: 0.87, ico: "🔍" }
    ]
    this.sparkData = this.stocks.map(() => {
      const d = []; for (let i = 0; i < 24; i++) d.push(40 + Math.random() * 40); return d
    })
    this.render()
    this.interval = setInterval(() => {
      this.stocks.forEach((st, i) => {
        st.p *= (1 + (Math.random() - 0.48) * 0.003)
        st.c += (Math.random() - 0.5) * 0.08
        this.sparkData[i].push(this.sparkData[i][this.sparkData[i].length - 1] + (Math.random() - 0.48) * 4)
        this.sparkData[i].shift()
      })
      this.render()
    }, 2500)
  }

  disconnect() { clearInterval(this.interval) }

  render() {
    this.listTarget.innerHTML = this.stocks.map((st, i) => {
      const up = st.c >= 0
      return `<div class="watchlist-row"><div class="wl-icon">${st.ico}</div><div class="wl-info"><div class="wl-sym">${st.s}</div><div class="wl-name">${st.n}</div></div><div class="wl-spark"><canvas id="spk${i}" width="112" height="48"></canvas></div><div class="wl-right"><div class="wl-price">${st.p.toFixed(2)}</div><div class="wl-chg ${up ? "up" : "dn"}">${up ? "↑" : "↓"} ${Math.abs(st.c).toFixed(2)}%</div></div></div>`
    }).join("")
    this.stocks.forEach((_, i) => this.drawSparkline(i))
  }

  drawSparkline(i) {
    const cv = document.getElementById("spk" + i)
    if (!cv) return
    const cx = cv.getContext("2d"), d = this.sparkData[i]
    const mn = Math.min(...d) - 5, mx = Math.max(...d) + 5, up = d[d.length - 1] >= d[0]
    cx.clearRect(0, 0, 112, 48)
    const g = cx.createLinearGradient(0, 48, 0, 0)
    g.addColorStop(0, "transparent")
    g.addColorStop(1, up ? "rgba(16,185,129,0.1)" : "rgba(244,63,94,0.08)")
    cx.beginPath(); cx.moveTo(0, 48)
    d.forEach((v, j) => cx.lineTo(j / (d.length - 1) * 112, 48 - (v - mn) / (mx - mn) * 38))
    cx.lineTo(112, 48); cx.closePath(); cx.fillStyle = g; cx.fill()
    cx.beginPath(); cx.strokeStyle = up ? "#10B981" : "#F43F5E"; cx.lineWidth = 1.5; cx.lineJoin = "round"
    d.forEach((v, j) => { const x = j / (d.length - 1) * 112, y = 48 - (v - mn) / (mx - mn) * 38; j === 0 ? cx.moveTo(x, y) : cx.lineTo(x, y) })
    cx.stroke()
  }
}
