import { Controller } from "@hotwired/stimulus"

// 50 floating blue dots with connection lines (<120px apart).
// Pauses when tab is hidden.
export default class extends Controller {
  connect() {
    this.canvas = this.element
    this.ctx = this.canvas.getContext("2d")
    this.particles = []
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
    this.init()
  }

  init() {
    this.particles = []
    for (let i = 0; i < 50; i++) {
      this.particles.push({
        x: Math.random() * this.w,
        y: Math.random() * this.h,
        r: Math.random() * 1.5 + 0.5,
        vx: (Math.random() - 0.5) * 0.15,
        vy: (Math.random() - 0.5) * 0.15,
        o: Math.random() * 0.3 + 0.05
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
    const { ctx, w, h, particles } = this
    ctx.clearRect(0, 0, w, h)

    particles.forEach(p => {
      p.x += p.vx
      p.y += p.vy
      if (p.x < 0) p.x = w
      if (p.x > w) p.x = 0
      if (p.y < 0) p.y = h
      if (p.y > h) p.y = 0
      ctx.beginPath()
      ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2)
      ctx.fillStyle = `rgba(59,130,246,${p.o})`
      ctx.fill()
    })

    for (let i = 0; i < particles.length; i++) {
      for (let j = i + 1; j < particles.length; j++) {
        const a = particles[i], b = particles[j]
        const d = Math.hypot(a.x - b.x, a.y - b.y)
        if (d < 120) {
          ctx.beginPath()
          ctx.strokeStyle = `rgba(59,130,246,${0.04 * (1 - d / 120)})`
          ctx.lineWidth = 0.5
          ctx.moveTo(a.x, a.y)
          ctx.lineTo(b.x, b.y)
          ctx.stroke()
        }
      }
    }
  }
}
