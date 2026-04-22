import { Controller } from "@hotwired/stimulus"

// Feature card 3: floating purple nodes with connection lines — neural net vibe.
// Uses requestAnimationFrame; pauses when not visible.
export default class extends Controller {
  connect() {
    this.canvas = this.element
    this.ctx = this.canvas.getContext("2d")
    this.rafId = null
    this.visible = true

    this.onResize = () => this.resize()
    window.addEventListener("resize", this.onResize)

    this.resize()
    this.observer = new IntersectionObserver(entries => {
      entries.forEach(e => {
        this.visible = e.isIntersecting
        if (this.visible) this.start()
        else this.stop()
      })
    }, { threshold: 0.1 })
    this.observer.observe(this.canvas)
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
    window.removeEventListener("resize", this.onResize)
    this.stop()
  }

  resize() {
    const dpr = window.devicePixelRatio || 1
    const W = this.canvas.clientWidth
    const H = this.canvas.clientHeight
    this.W = W
    this.H = H
    this.canvas.width = W * dpr
    this.canvas.height = H * dpr
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    this.nodes = []
    for (let i = 0; i < 18; i++) {
      this.nodes.push({
        x: Math.random() * W,
        y: Math.random() * H,
        vx: (Math.random() - 0.5) * 0.25,
        vy: (Math.random() - 0.5) * 0.25
      })
    }
  }

  start() {
    if (this.rafId) return
    const loop = () => {
      if (!document.hidden && this.visible) this.draw()
      this.rafId = requestAnimationFrame(loop)
    }
    this.rafId = requestAnimationFrame(loop)
  }

  stop() {
    if (this.rafId) cancelAnimationFrame(this.rafId)
    this.rafId = null
  }

  draw() {
    const { ctx, nodes, W, H } = this
    ctx.clearRect(0, 0, W, H)
    nodes.forEach(n => {
      n.x += n.vx; n.y += n.vy
      if (n.x < 0 || n.x > W) n.vx *= -1
      if (n.y < 0 || n.y > H) n.vy *= -1
    })
    for (let i = 0; i < nodes.length; i++) {
      for (let j = i + 1; j < nodes.length; j++) {
        const d = Math.hypot(nodes[i].x - nodes[j].x, nodes[i].y - nodes[j].y)
        if (d < 90) {
          ctx.beginPath()
          ctx.strokeStyle = `rgba(139,92,246,${0.15 * (1 - d / 90)})`
          ctx.lineWidth = 0.8
          ctx.moveTo(nodes[i].x, nodes[i].y)
          ctx.lineTo(nodes[j].x, nodes[j].y)
          ctx.stroke()
        }
      }
    }
    nodes.forEach(n => {
      ctx.beginPath()
      ctx.arc(n.x, n.y, 2.5, 0, Math.PI * 2)
      ctx.fillStyle = "rgba(139,92,246,0.4)"
      ctx.fill()
      ctx.beginPath()
      ctx.arc(n.x, n.y, 5, 0, Math.PI * 2)
      ctx.fillStyle = "rgba(139,92,246,0.08)"
      ctx.fill()
    })
  }
}
