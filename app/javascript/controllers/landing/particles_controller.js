import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.canvas = this.element
    this.ctx = this.canvas.getContext("2d")
    this.particles = []
    this.resize()
    this.resizeHandler = () => this.resize()
    window.addEventListener("resize", this.resizeHandler)
    this.draw()
  }

  disconnect() {
    window.removeEventListener("resize", this.resizeHandler)
    if (this.raf) cancelAnimationFrame(this.raf)
  }

  resize() {
    this.w = this.canvas.width = window.innerWidth
    this.h = this.canvas.height = window.innerHeight
    this.particles = []
    for (let i = 0; i < 50; i++) {
      this.particles.push({
        x: Math.random() * this.w, y: Math.random() * this.h,
        r: Math.random() * 1.5 + 0.5, vx: (Math.random() - 0.5) * 0.15,
        vy: (Math.random() - 0.5) * 0.15, o: Math.random() * 0.3 + 0.05
      })
    }
  }

  draw() {
    this.ctx.clearRect(0, 0, this.w, this.h)
    this.particles.forEach(p => {
      p.x += p.vx; p.y += p.vy
      if (p.x < 0) p.x = this.w; if (p.x > this.w) p.x = 0
      if (p.y < 0) p.y = this.h; if (p.y > this.h) p.y = 0
      this.ctx.beginPath()
      this.ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2)
      this.ctx.fillStyle = `rgba(59,130,246,${p.o})`
      this.ctx.fill()
    })
    for (let i = 0; i < this.particles.length; i++) {
      for (let j = i + 1; j < this.particles.length; j++) {
        const d = Math.hypot(this.particles[i].x - this.particles[j].x, this.particles[i].y - this.particles[j].y)
        if (d < 120) {
          this.ctx.beginPath()
          this.ctx.strokeStyle = `rgba(59,130,246,${0.04 * (1 - d / 120)})`
          this.ctx.lineWidth = 0.5
          this.ctx.moveTo(this.particles[i].x, this.particles[i].y)
          this.ctx.lineTo(this.particles[j].x, this.particles[j].y)
          this.ctx.stroke()
        }
      }
    }
    this.raf = requestAnimationFrame(() => this.draw())
  }
}
