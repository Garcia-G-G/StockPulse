import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas", "value", "change"]

  connect() {
    this.chartData = []
    for (let i = 0; i < 90; i++) {
      this.chartData.push(44000 + Math.random() * 4000 + i * 50 + Math.sin(i * 0.2) * 800)
    }
    // Wait for layout, then draw
    setTimeout(() => this.draw(), 100)
    this.interval = setInterval(() => this.update(), 3000)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  draw() {
    const c = this.canvasTarget
    if (!c) return
    const W = c.offsetWidth
    const H = c.offsetHeight
    if (W === 0 || H === 0) return

    const ctx = c.getContext("2d")
    const dpr = devicePixelRatio || 1
    c.width = W * dpr
    c.height = H * dpr
    ctx.scale(dpr, dpr)

    const d = this.chartData
    const min = Math.min(...d) * 0.98
    const max = Math.max(...d) * 1.02
    const step = W / (d.length - 1)

    // Area fill
    const g = ctx.createLinearGradient(0, 0, 0, H)
    g.addColorStop(0, "rgba(59,130,246,0.2)")
    g.addColorStop(0.7, "rgba(59,130,246,0.02)")
    g.addColorStop(1, "transparent")
    ctx.beginPath()
    ctx.moveTo(0, H)
    d.forEach((v, i) => ctx.lineTo(i * step, H - (v - min) / (max - min) * H * 0.85))
    ctx.lineTo(W, H)
    ctx.closePath()
    ctx.fillStyle = g
    ctx.fill()

    // Line stroke
    ctx.beginPath()
    ctx.strokeStyle = "#3B82F6"
    ctx.lineWidth = 2
    ctx.lineJoin = "round"
    d.forEach((v, i) => {
      const x = i * step
      const y = H - (v - min) / (max - min) * H * 0.85
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
    })
    ctx.stroke()

    // Glow dot at end
    const lx = (d.length - 1) * step
    const ly = H - (d[d.length - 1] - min) / (max - min) * H * 0.85
    ctx.beginPath()
    ctx.arc(lx, ly, 5, 0, Math.PI * 2)
    ctx.fillStyle = "rgba(59,130,246,0.25)"
    ctx.fill()
    ctx.beginPath()
    ctx.arc(lx, ly, 2.5, 0, Math.PI * 2)
    ctx.fillStyle = "#3B82F6"
    ctx.fill()
  }

  update() {
    this.chartData.push(this.chartData[this.chartData.length - 1] * (1 + (Math.random() - 0.47) * 0.004))
    this.chartData.shift()
    this.draw()
    const v = this.chartData[this.chartData.length - 1]
    if (this.hasValueTarget) {
      this.valueTarget.textContent = "$" + v.toLocaleString("en", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    }
  }
}
