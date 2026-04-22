import { Controller } from "@hotwired/stimulus"

// Hero dashboard preview — portfolio area chart with gradient fill,
// gradient-stroked line, glow dot at current price. Random-walks every 1.8s.
export default class extends Controller {
  static targets = ["canvas", "value"]

  connect() {
    this.data = []
    for (let i = 0; i < 90; i++) {
      this.data.push(22000 + Math.random() * 4000 + i * 30 + Math.sin(i * 0.2) * 500)
    }
    this.draw()
    this.interval = setInterval(() => this.tick(), 1800)

    this.onResize = () => this.draw()
    this.onVisibility = () => this.handleVisibility()
    window.addEventListener("resize", this.onResize)
    document.addEventListener("visibilitychange", this.onVisibility)
  }

  disconnect() {
    if (this.interval) clearInterval(this.interval)
    window.removeEventListener("resize", this.onResize)
    document.removeEventListener("visibilitychange", this.onVisibility)
  }

  handleVisibility() {
    if (document.hidden && this.interval) {
      clearInterval(this.interval)
      this.interval = null
    } else if (!document.hidden && !this.interval) {
      this.interval = setInterval(() => this.tick(), 1800)
    }
  }

  tick() {
    this.data.push(this.data[this.data.length - 1] * (1 + (Math.random() - 0.47) * 0.004))
    this.data.shift()
    this.draw()
    if (this.hasValueTarget) {
      const v = this.data[this.data.length - 1]
      this.valueTarget.textContent = "$" + v.toLocaleString("en", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    }
  }

  draw() {
    if (!this.hasCanvasTarget) return
    const canvas = this.canvasTarget
    const dpr = window.devicePixelRatio || 1
    const W = canvas.clientWidth, H = canvas.clientHeight
    if (W === 0 || H === 0) return
    canvas.width = W * dpr
    canvas.height = H * dpr
    const ctx = canvas.getContext("2d")
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    ctx.clearRect(0, 0, W, H)

    const data = this.data
    const min = Math.min(...data) * 0.98
    const max = Math.max(...data) * 1.02
    const step = W / (data.length - 1)

    // Gradient fill
    const g = ctx.createLinearGradient(0, 0, 0, H)
    g.addColorStop(0, "rgba(59,130,246,0.18)")
    g.addColorStop(0.6, "rgba(99,102,241,0.04)")
    g.addColorStop(1, "transparent")
    ctx.beginPath()
    ctx.moveTo(0, H)
    data.forEach((v, i) => ctx.lineTo(i * step, H - ((v - min) / (max - min)) * H * 0.85))
    ctx.lineTo(W, H)
    ctx.closePath()
    ctx.fillStyle = g
    ctx.fill()

    // Gradient stroke line
    const sg = ctx.createLinearGradient(0, 0, W, 0)
    sg.addColorStop(0, "#3B82F6")
    sg.addColorStop(1, "#6366F1")
    ctx.beginPath()
    ctx.strokeStyle = sg
    ctx.lineWidth = 2.2
    ctx.lineJoin = "round"
    data.forEach((v, i) => {
      const x = i * step
      const y = H - ((v - min) / (max - min)) * H * 0.85
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
    })
    ctx.stroke()

    // Glow dot at end
    const lx = (data.length - 1) * step
    const ly = H - ((data[data.length - 1] - min) / (max - min)) * H * 0.85
    ctx.beginPath()
    ctx.arc(lx, ly, 6, 0, Math.PI * 2)
    ctx.fillStyle = "rgba(99,102,241,0.25)"
    ctx.fill()
    ctx.beginPath()
    ctx.arc(lx, ly, 3, 0, Math.PI * 2)
    ctx.fillStyle = "#6366F1"
    ctx.fill()
  }
}
