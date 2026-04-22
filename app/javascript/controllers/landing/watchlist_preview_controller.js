import { Controller } from "@hotwired/stimulus"

// Renders the hero-preview's 5-stock watchlist with sparklines and
// re-renders every 2.5s with new "live" random values.
export default class extends Controller {
  connect() {
    this.stocks = [
      { s: "AAPL",  n: "Apple",     p: 198.45, c: 1.23,  ico: "🍎" },
      { s: "NVDA",  n: "NVIDIA",    p: 924.56, c: 2.34,  ico: "🟢" },
      { s: "TSLA",  n: "Tesla",     p: 178.30, c: -1.12, ico: "⚡" },
      { s: "MSFT",  n: "Microsoft", p: 445.12, c: -0.45, ico: "🔷" },
      { s: "GOOGL", n: "Alphabet",  p: 178.90, c: 0.87,  ico: "🔍" }
    ]
    this.sparkData = this.stocks.map(() => {
      const d = []
      for (let i = 0; i < 24; i++) d.push(40 + Math.random() * 40)
      return d
    })

    this.render()
    this.interval = setInterval(() => this.tick(), 2500)

    this.onVisibility = () => this.handleVisibility()
    document.addEventListener("visibilitychange", this.onVisibility)
  }

  disconnect() {
    if (this.interval) clearInterval(this.interval)
    document.removeEventListener("visibilitychange", this.onVisibility)
  }

  handleVisibility() {
    if (document.hidden && this.interval) {
      clearInterval(this.interval)
      this.interval = null
    } else if (!document.hidden && !this.interval) {
      this.interval = setInterval(() => this.tick(), 2500)
    }
  }

  tick() {
    this.stocks.forEach((st, i) => {
      st.p *= (1 + (Math.random() - 0.48) * 0.003)
      st.c += (Math.random() - 0.5) * 0.08
      st.c = Math.max(-5, Math.min(5, st.c))
      const d = this.sparkData[i]
      d.push(d[d.length - 1] + (Math.random() - 0.48) * 4)
      d.shift()
    })
    this.render()
  }

  render() {
    this.element.innerHTML = this.stocks.map((st, i) => {
      const up = st.c >= 0
      return `
        <div class="watchlist-row">
          <div class="wl-icon">${st.ico}</div>
          <div class="wl-info">
            <div class="wl-sym">${st.s}</div>
            <div class="wl-name">${st.n}</div>
          </div>
          <div class="wl-spark"><canvas data-spark-index="${i}"></canvas></div>
          <div class="wl-right">
            <div class="wl-price">${st.p.toFixed(2)}</div>
            <div class="wl-chg ${up ? "up" : "dn"}">${up ? "↑" : "↓"} ${Math.abs(st.c).toFixed(2)}%</div>
          </div>
        </div>
      `
    }).join("")

    this.stocks.forEach((_, i) => this.drawSpark(i))
  }

  drawSpark(i) {
    const canvas = this.element.querySelector(`canvas[data-spark-index="${i}"]`)
    if (!canvas) return
    const dpr = window.devicePixelRatio || 1
    const W = canvas.clientWidth || 56
    const H = canvas.clientHeight || 24
    canvas.width = W * dpr
    canvas.height = H * dpr
    const ctx = canvas.getContext("2d")
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    ctx.clearRect(0, 0, W, H)

    const d = this.sparkData[i]
    const mn = Math.min(...d) - 5
    const mx = Math.max(...d) + 5
    const up = d[d.length - 1] >= d[0]
    const color = up ? "#10B981" : "#F43F5E"
    const fill = up ? "rgba(16,185,129,0.1)" : "rgba(244,63,94,0.08)"

    const xAt = j => (j / (d.length - 1)) * W
    const yAt = v => H - ((v - mn) / (mx - mn)) * (H - 4) - 2

    const g = ctx.createLinearGradient(0, H, 0, 0)
    g.addColorStop(0, "transparent")
    g.addColorStop(1, fill)
    ctx.beginPath()
    ctx.moveTo(0, H)
    d.forEach((v, j) => ctx.lineTo(xAt(j), yAt(v)))
    ctx.lineTo(W, H)
    ctx.closePath()
    ctx.fillStyle = g
    ctx.fill()

    ctx.beginPath()
    ctx.strokeStyle = color
    ctx.lineWidth = 1.5
    ctx.lineJoin = "round"
    d.forEach((v, j) => {
      const x = xAt(j), y = yAt(v)
      j === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
    })
    ctx.stroke()
  }
}
