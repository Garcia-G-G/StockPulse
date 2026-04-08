import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas", "value", "change"]

  connect() {
    this.chartData = []
    for (let i = 0; i < 90; i++) this.chartData.push(22000 + Math.random() * 4000 + i * 30 + Math.sin(i * 0.2) * 500)
    setTimeout(() => this.draw(), 150)
    this.interval = setInterval(() => this.update(), 1800)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  draw() {
    const c = this.canvasTarget
    const ctx = c.getContext("2d")
    const dpr = devicePixelRatio || 1
    c.width = c.offsetWidth * dpr
    c.height = c.offsetHeight * dpr
    ctx.scale(dpr, dpr)
    const W = c.offsetWidth, H = c.offsetHeight
    const min = Math.min(...this.chartData) * 0.98, max = Math.max(...this.chartData) * 1.02
    const step = W / (this.chartData.length - 1)

    const g = ctx.createLinearGradient(0, 0, 0, H)
    g.addColorStop(0, "rgba(59,130,246,0.18)")
    g.addColorStop(0.6, "rgba(99,102,241,0.04)")
    g.addColorStop(1, "transparent")
    ctx.beginPath(); ctx.moveTo(0, H)
    this.chartData.forEach((v, i) => ctx.lineTo(i * step, H - (v - min) / (max - min) * H * 0.85))
    ctx.lineTo(W, H); ctx.closePath(); ctx.fillStyle = g; ctx.fill()

    const sg = ctx.createLinearGradient(0, 0, W, 0)
    sg.addColorStop(0, "#3B82F6"); sg.addColorStop(1, "#6366F1")
    ctx.beginPath(); ctx.strokeStyle = sg; ctx.lineWidth = 2.2; ctx.lineJoin = "round"
    this.chartData.forEach((v, i) => {
      const x = i * step, y = H - (v - min) / (max - min) * H * 0.85
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
    })
    ctx.stroke()

    const lx = (this.chartData.length - 1) * step, ly = H - (this.chartData[this.chartData.length - 1] - min) / (max - min) * H * 0.85
    ctx.beginPath(); ctx.arc(lx, ly, 6, 0, Math.PI * 2); ctx.fillStyle = "rgba(99,102,241,0.25)"; ctx.fill()
    ctx.beginPath(); ctx.arc(lx, ly, 3, 0, Math.PI * 2); ctx.fillStyle = "#6366F1"; ctx.fill()
  }

  update() {
    this.chartData.push(this.chartData[this.chartData.length - 1] * (1 + (Math.random() - 0.47) * 0.004))
    this.chartData.shift()
    this.draw()
    const v = this.chartData[this.chartData.length - 1]
    this.valueTarget.textContent = "$" + v.toLocaleString("en", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
  }
}
