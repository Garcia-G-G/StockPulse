import { Controller } from "@hotwired/stimulus"

// Feature card 1: animated streaming line chart, updates every 500ms.
// Only ticks while the card is visible on screen.
export default class extends Controller {
  connect() {
    this.canvas = this.element
    this.ctx = this.canvas.getContext("2d")
    this.data = []
    for (let i = 0; i < 70; i++) this.data.push(40 + Math.random() * 40)
    this.draw()

    this.visible = true
    this.intervalId = null
    this.onResize = () => this.draw()
    window.addEventListener("resize", this.onResize)

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

  start() {
    if (this.intervalId) return
    this.intervalId = setInterval(() => this.tick(), 500)
  }

  stop() {
    if (this.intervalId) clearInterval(this.intervalId)
    this.intervalId = null
  }

  tick() {
    if (document.hidden) return
    this.data.push(this.data[this.data.length - 1] + (Math.random() - 0.48) * 5)
    this.data.shift()
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

    const d = this.data
    const mn = Math.min(...d) - 10
    const mx = Math.max(...d) + 10

    const g = ctx.createLinearGradient(0, 0, 0, H)
    g.addColorStop(0, "rgba(59,130,246,0.15)")
    g.addColorStop(1, "transparent")
    ctx.beginPath()
    ctx.moveTo(0, H)
    d.forEach((v, i) => ctx.lineTo((i / (d.length - 1)) * W, H - ((v - mn) / (mx - mn)) * H * 0.8))
    ctx.lineTo(W, H)
    ctx.closePath()
    ctx.fillStyle = g
    ctx.fill()

    const sg = ctx.createLinearGradient(0, 0, W, 0)
    sg.addColorStop(0, "#3B82F6")
    sg.addColorStop(1, "#6366F1")
    ctx.beginPath()
    ctx.strokeStyle = sg
    ctx.lineWidth = 1.8
    ctx.lineJoin = "round"
    d.forEach((v, i) => {
      const x = (i / (d.length - 1)) * W
      const y = H - ((v - mn) / (mx - mn)) * H * 0.8
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
    })
    ctx.stroke()
  }
}
