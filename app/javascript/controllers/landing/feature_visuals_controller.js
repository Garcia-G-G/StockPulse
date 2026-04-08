import { Controller } from "@hotwired/stimulus"

// Feature card canvas visuals. Only animate when visible.
// Stream and bars use setInterval. Neural uses rAF but only when in viewport.
export default class extends Controller {
  static targets = ["stream", "alerts", "neural"]

  connect() {
    this.streamData = []
    for (let i = 0; i < 50; i++) this.streamData.push(40 + Math.random() * 40)
    this.barData = []
    for (let i = 0; i < 20; i++) this.barData.push(Math.random() * 80 + 10)
    this.nodes = []
    for (let i = 0; i < 12; i++) this.nodes.push({
      x: Math.random() * 300, y: Math.random() * 140,
      vx: (Math.random() - 0.5) * 0.15, vy: (Math.random() - 0.5) * 0.15
    })

    this.neuralVisible = false
    this.sizedStream = false
    this.sizedAlerts = false
    this.sizedNeural = false

    // Only animate when visible
    this.observer = new IntersectionObserver(entries => {
      for (const e of entries) {
        if (e.target === this.element) {
          if (e.isIntersecting) this.startAnimations()
          else this.stopAnimations()
        }
      }
    }, { threshold: 0.1 })
    this.observer.observe(this.element)
  }

  disconnect() {
    this.stopAnimations()
    this.observer?.disconnect()
  }

  startAnimations() {
    if (!this.streamInterval) {
      this.drawStream()
      this.drawBars()
      this.streamInterval = setInterval(() => {
        this.streamData.push(this.streamData[this.streamData.length - 1] + (Math.random() - 0.48) * 5)
        this.streamData.shift()
        this.drawStream()
      }, 800)
      this.barInterval = setInterval(() => {
        const i = Math.floor(Math.random() * this.barData.length)
        this.barData[i] = Math.max(5, Math.min(95, this.barData[i] + (Math.random() - 0.5) * 18))
        this.drawBars()
      }, 600)
    }
    this.neuralVisible = true
    this.drawNeural()
  }

  stopAnimations() {
    clearInterval(this.streamInterval)
    clearInterval(this.barInterval)
    this.streamInterval = null
    this.barInterval = null
    this.neuralVisible = false
    if (this.neuralRaf) cancelAnimationFrame(this.neuralRaf)
  }

  sizeCanvas(c) {
    const dp = 2
    c.width = c.offsetWidth * dp
    c.height = c.offsetHeight * dp
    return c.getContext("2d")
  }

  drawStream() {
    if (!this.hasStreamTarget) return
    const c = this.streamTarget
    // Only resize once
    if (!this.sizedStream) { this.sizeCanvas(c); this.sizedStream = true }
    const ctx = c.getContext("2d"), dp = 2
    const W = c.width / dp, H = c.height / dp, d = this.streamData
    ctx.save(); ctx.scale(dp, dp)
    const mn = Math.min(...d) - 10, mx = Math.max(...d) + 10
    ctx.clearRect(0, 0, W, H)
    const g = ctx.createLinearGradient(0, 0, 0, H)
    g.addColorStop(0, "rgba(59,130,246,0.12)")
    g.addColorStop(1, "transparent")
    ctx.beginPath(); ctx.moveTo(0, H)
    d.forEach((v, i) => ctx.lineTo(i / (d.length - 1) * W, H - (v - mn) / (mx - mn) * H * 0.8))
    ctx.lineTo(W, H); ctx.closePath(); ctx.fillStyle = g; ctx.fill()
    ctx.beginPath(); ctx.strokeStyle = "#3B82F6"; ctx.lineWidth = 1.5; ctx.lineJoin = "round"
    d.forEach((v, i) => {
      const x = i / (d.length - 1) * W, y = H - (v - mn) / (mx - mn) * H * 0.8
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
    })
    ctx.stroke(); ctx.restore()
  }

  drawBars() {
    if (!this.hasAlertsTarget) return
    const c = this.alertsTarget
    if (!this.sizedAlerts) { this.sizeCanvas(c); this.sizedAlerts = true }
    const ctx = c.getContext("2d"), dp = 2
    const W = c.width / dp, H = c.height / dp, bw = W / this.barData.length - 2
    ctx.save(); ctx.scale(dp, dp)
    ctx.clearRect(0, 0, W, H)
    this.barData.forEach((v, i) => {
      const x = i * (bw + 2) + 1, h = v / 100 * H * 0.8, up = v > 50
      ctx.fillStyle = up ? "rgba(16,185,129,0.18)" : "rgba(244,63,94,0.14)"
      ctx.beginPath(); ctx.roundRect(x, H - h, bw, h, 2); ctx.fill()
    })
    ctx.restore()
  }

  drawNeural() {
    if (!this.neuralVisible || !this.hasNeuralTarget) return
    const c = this.neuralTarget
    if (!this.sizedNeural) { this.sizeCanvas(c); this.sizedNeural = true }
    const ctx = c.getContext("2d"), dp = 2
    const W = c.width / dp, H = c.height / dp
    ctx.save(); ctx.scale(dp, dp)
    ctx.clearRect(0, 0, W, H)
    this.nodes.forEach(n => {
      n.x += n.vx; n.y += n.vy
      if (n.x < 0 || n.x > W) n.vx *= -1
      if (n.y < 0 || n.y > H) n.vy *= -1
    })
    for (let i = 0; i < this.nodes.length; i++) {
      for (let j = i + 1; j < this.nodes.length; j++) {
        const d = Math.hypot(this.nodes[i].x - this.nodes[j].x, this.nodes[i].y - this.nodes[j].y)
        if (d < 90) {
          ctx.beginPath()
          ctx.strokeStyle = `rgba(139,92,246,${0.12 * (1 - d / 90)})`
          ctx.lineWidth = 0.6
          ctx.moveTo(this.nodes[i].x, this.nodes[i].y)
          ctx.lineTo(this.nodes[j].x, this.nodes[j].y)
          ctx.stroke()
        }
      }
    }
    this.nodes.forEach(n => {
      ctx.beginPath(); ctx.arc(n.x, n.y, 2, 0, Math.PI * 2)
      ctx.fillStyle = "rgba(139,92,246,0.3)"; ctx.fill()
    })
    ctx.restore()
    this.neuralRaf = requestAnimationFrame(() => this.drawNeural())
  }
}
