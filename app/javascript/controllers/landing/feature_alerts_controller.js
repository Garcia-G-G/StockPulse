import { Controller } from "@hotwired/stimulus"

// Feature card 2: animated bar chart — green/red bars, updates every 350ms.
// Only ticks while visible.
export default class extends Controller {
  connect() {
    this.canvas = this.element
    this.ctx = this.canvas.getContext("2d")
    this.bars = []
    for (let i = 0; i < 28; i++) this.bars.push(Math.random() * 80 + 10)
    this.draw()

    this.intervalId = null
    this.onResize = () => this.draw()
    window.addEventListener("resize", this.onResize)

    this.observer = new IntersectionObserver(entries => {
      entries.forEach(e => {
        if (e.isIntersecting) this.start()
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

  start() {
    if (this.intervalId) return
    this.intervalId = setInterval(() => this.tick(), 350)
  }

  stop() {
    if (this.intervalId) clearInterval(this.intervalId)
    this.intervalId = null
  }

  tick() {
    if (document.hidden) return
    const i = Math.floor(Math.random() * this.bars.length)
    this.bars[i] = Math.max(5, Math.min(95, this.bars[i] + (Math.random() - 0.5) * 18))
    this.draw()
  }

  draw() {
    const c = this.canvas, ctx = this.ctx
    const dpr = window.devicePixelRatio || 1
    const W = c.clientWidth, H = c.clientHeight
    if (W === 0 || H === 0) return
    c.width = W * dpr
    c.height = H * dpr
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    ctx.clearRect(0, 0, W, H)

    const bw = W / this.bars.length - 2
    this.bars.forEach((v, i) => {
      const x = i * (bw + 2) + 1
      const h = (v / 100) * H * 0.8
      const up = v > 50
      const g = ctx.createLinearGradient(0, H, 0, H - h)
      g.addColorStop(0, up ? "rgba(16,185,129,0.05)" : "rgba(244,63,94,0.05)")
      g.addColorStop(1, up ? "rgba(16,185,129,0.25)" : "rgba(244,63,94,0.2)")
      ctx.fillStyle = g
      ctx.beginPath()
      if (ctx.roundRect) ctx.roundRect(x, H - h, bw, h, 2)
      else ctx.rect(x, H - h, bw, h)
      ctx.fill()
    })
  }
}
