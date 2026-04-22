import { Controller } from "@hotwired/stimulus"

// Background aurora: 14 wavy lines drifting, faint blue/green/indigo/cyan.
// Pauses when the tab is hidden.
export default class extends Controller {
  connect() {
    this.canvas = this.element
    this.ctx = this.canvas.getContext("2d")
    this.lines = []
    this.t = 0
    this.rafId = null
    this.onResize = () => this.resize()
    this.onVisibility = () => this.handleVisibility()

    window.addEventListener("resize", this.onResize)
    document.addEventListener("visibilitychange", this.onVisibility)

    this.resize()
    this.start()
  }

  disconnect() {
    window.removeEventListener("resize", this.onResize)
    document.removeEventListener("visibilitychange", this.onVisibility)
    this.stop()
  }

  resize() {
    this.w = this.canvas.width = window.innerWidth
    this.h = this.canvas.height = window.innerHeight
    this.initLines()
  }

  initLines() {
    const colors = [
      "rgba(59,130,246,0.06)",
      "rgba(16,185,129,0.04)",
      "rgba(99,102,241,0.05)",
      "rgba(6,182,212,0.03)"
    ]
    this.lines = []
    for (let i = 0; i < 14; i++) {
      const pts = []
      const baseY = this.h * 0.2 + Math.random() * this.h * 0.6
      for (let x = 0; x <= this.w; x += 3) pts.push({ x, y: baseY })
      this.lines.push({
        pts,
        speed: 0.15 + Math.random() * 0.35,
        phase: Math.random() * Math.PI * 2,
        amp: 15 + Math.random() * 35,
        freq: 0.001 + Math.random() * 0.002,
        color: colors[i % 4]
      })
    }
  }

  start() {
    if (this.rafId) return
    const loop = () => {
      this.draw()
      this.rafId = requestAnimationFrame(loop)
    }
    this.rafId = requestAnimationFrame(loop)
  }

  stop() {
    if (this.rafId) cancelAnimationFrame(this.rafId)
    this.rafId = null
  }

  handleVisibility() {
    if (document.hidden) this.stop()
    else this.start()
  }

  draw() {
    const { ctx, w, h } = this
    ctx.clearRect(0, 0, w, h)
    this.t += 0.002
    this.lines.forEach(l => {
      ctx.beginPath()
      ctx.strokeStyle = l.color
      ctx.lineWidth = 1.5
      l.pts.forEach((p, i) => {
        const y = p.y
          + Math.sin(p.x * l.freq + this.t * l.speed + l.phase) * l.amp
          + Math.sin(p.x * l.freq * 2.3 + this.t * l.speed * 0.7) * l.amp * 0.4
        i === 0 ? ctx.moveTo(p.x, y) : ctx.lineTo(p.x, y)
      })
      ctx.stroke()
    })
  }
}
