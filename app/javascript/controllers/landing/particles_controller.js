import { Controller } from "@hotwired/stimulus"

// Sparse floating dots. No connections (they're barely visible and expensive).
// Throttled to ~15fps — these move so slowly it doesn't matter.
export default class extends Controller {
  connect() {
    this.canvas = this.element
    this.ctx = this.canvas.getContext("2d")
    this.particles = []
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
    this.particles = []
    for (let i = 0; i < 25; i++) {
      this.particles.push({
        x: Math.random() * this.w,
        y: Math.random() * this.h,
        r: Math.random() * 1.2 + 0.4,
        vx: (Math.random() - 0.5) * 0.08,
        vy: (Math.random() - 0.5) * 0.08,
        o: Math.random() * 0.15 + 0.03
      })
    }
  }

  draw(ts) {
    if (ts - this.lastFrame < 66) { // ~15fps
      this.raf = requestAnimationFrame((t) => this.draw(t))
      return
    }
    this.lastFrame = ts

    this.ctx.clearRect(0, 0, this.w, this.h)
    for (const p of this.particles) {
      p.x += p.vx
      p.y += p.vy
      if (p.x < 0) p.x = this.w
      if (p.x > this.w) p.x = 0
      if (p.y < 0) p.y = this.h
      if (p.y > this.h) p.y = 0
      this.ctx.beginPath()
      this.ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2)
      this.ctx.fillStyle = `rgba(59,130,246,${p.o})`
      this.ctx.fill()
    }
    this.raf = requestAnimationFrame((t) => this.draw(t))
  }
}
