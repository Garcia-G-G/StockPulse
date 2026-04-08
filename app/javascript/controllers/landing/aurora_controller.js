import { Controller } from "@hotwired/stimulus"

// Renders a few slow-moving gradient lines as subtle background texture.
// Throttled to ~20fps and uses coarser point spacing for performance.
export default class extends Controller {
  connect() {
    this.canvas = this.element
    this.ctx = this.canvas.getContext("2d")
    this.t = 0
    this.lines = []
    this.resize()
    this.resizeHandler = () => this.resize()
    window.addEventListener("resize", this.resizeHandler)
    this.lastFrame = 0
    this.draw(0)
  }

  disconnect() {
    window.removeEventListener("resize", this.resizeHandler)
    if (this.raf) cancelAnimationFrame(this.raf)
  }

  resize() {
    this.w = this.canvas.width = window.innerWidth
    this.h = this.canvas.height = window.innerHeight
    this.initLines()
  }

  initLines() {
    this.lines = []
    // 5 lines instead of 14, points every 12px instead of 3
    const colors = [
      "rgba(59,130,246,0.04)",
      "rgba(16,185,129,0.025)",
      "rgba(99,102,241,0.035)",
      "rgba(59,130,246,0.03)",
      "rgba(6,182,212,0.02)"
    ]
    for (let i = 0; i < 5; i++) {
      const pts = []
      const baseY = this.h * 0.25 + Math.random() * this.h * 0.5
      for (let x = 0; x <= this.w; x += 12) pts.push({ x, y: baseY })
      this.lines.push({
        pts,
        speed: 0.08 + Math.random() * 0.15,
        phase: Math.random() * Math.PI * 2,
        amp: 20 + Math.random() * 40,
        freq: 0.0008 + Math.random() * 0.0012,
        color: colors[i]
      })
    }
  }

  draw(ts) {
    // Throttle to ~20fps
    if (ts - this.lastFrame < 50) {
      this.raf = requestAnimationFrame((t) => this.draw(t))
      return
    }
    this.lastFrame = ts

    this.ctx.clearRect(0, 0, this.w, this.h)
    this.t += 0.003
    for (const l of this.lines) {
      this.ctx.beginPath()
      this.ctx.strokeStyle = l.color
      this.ctx.lineWidth = 1.5
      for (let i = 0; i < l.pts.length; i++) {
        const p = l.pts[i]
        const y = p.y + Math.sin(p.x * l.freq + this.t * l.speed + l.phase) * l.amp
        i === 0 ? this.ctx.moveTo(p.x, y) : this.ctx.lineTo(p.x, y)
      }
      this.ctx.stroke()
    }
    this.raf = requestAnimationFrame((t) => this.draw(t))
  }
}
