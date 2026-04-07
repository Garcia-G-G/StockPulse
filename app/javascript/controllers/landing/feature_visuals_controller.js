import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["stream", "alerts", "neural"]

  connect() {
    this.streamData = []; for (let i = 0; i < 70; i++) this.streamData.push(40 + Math.random() * 40)
    this.barData = []; for (let i = 0; i < 28; i++) this.barData.push(Math.random() * 80 + 10)
    this.nodes = []; for (let i = 0; i < 18; i++) this.nodes.push({ x: Math.random() * 300, y: Math.random() * 140, vx: (Math.random() - 0.5) * 0.25, vy: (Math.random() - 0.5) * 0.25 })

    this.drawStream(); this.drawBars(); this.drawNeural()
    this.streamInterval = setInterval(() => { this.streamData.push(this.streamData[this.streamData.length - 1] + (Math.random() - 0.48) * 5); this.streamData.shift(); this.drawStream() }, 500)
    this.barInterval = setInterval(() => { const i = Math.floor(Math.random() * this.barData.length); this.barData[i] = Math.max(5, Math.min(95, this.barData[i] + (Math.random() - 0.5) * 18)); this.drawBars() }, 350)
  }

  disconnect() {
    clearInterval(this.streamInterval); clearInterval(this.barInterval)
    if (this.neuralRaf) cancelAnimationFrame(this.neuralRaf)
  }

  drawStream() {
    if (!this.hasStreamTarget) return
    const c = this.streamTarget, ctx = c.getContext("2d"), dp = 2
    c.width = c.offsetWidth * dp; c.height = c.offsetHeight * dp; ctx.scale(dp, dp)
    const W = c.offsetWidth, H = c.offsetHeight, d = this.streamData
    const mn = Math.min(...d) - 10, mx = Math.max(...d) + 10
    ctx.clearRect(0, 0, W, H)
    const g = ctx.createLinearGradient(0, 0, 0, H); g.addColorStop(0, "rgba(59,130,246,0.15)"); g.addColorStop(1, "transparent")
    ctx.beginPath(); ctx.moveTo(0, H); d.forEach((v, i) => ctx.lineTo(i / (d.length - 1) * W, H - (v - mn) / (mx - mn) * H * 0.8))
    ctx.lineTo(W, H); ctx.closePath(); ctx.fillStyle = g; ctx.fill()
    const sg = ctx.createLinearGradient(0, 0, W, 0); sg.addColorStop(0, "#3B82F6"); sg.addColorStop(1, "#6366F1")
    ctx.beginPath(); ctx.strokeStyle = sg; ctx.lineWidth = 1.8; ctx.lineJoin = "round"
    d.forEach((v, i) => { const x = i / (d.length - 1) * W, y = H - (v - mn) / (mx - mn) * H * 0.8; i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y) }); ctx.stroke()
  }

  drawBars() {
    if (!this.hasAlertsTarget) return
    const c = this.alertsTarget, ctx = c.getContext("2d"), dp = 2
    c.width = c.offsetWidth * dp; c.height = c.offsetHeight * dp; ctx.scale(dp, dp)
    const W = c.offsetWidth, H = c.offsetHeight, bw = W / this.barData.length - 2
    ctx.clearRect(0, 0, W, H)
    this.barData.forEach((v, i) => {
      const x = i * (bw + 2) + 1, h = v / 100 * H * 0.8, up = v > 50
      const g = ctx.createLinearGradient(0, H, 0, H - h)
      g.addColorStop(0, up ? "rgba(16,185,129,0.05)" : "rgba(244,63,94,0.05)")
      g.addColorStop(1, up ? "rgba(16,185,129,0.25)" : "rgba(244,63,94,0.2)")
      ctx.fillStyle = g; ctx.beginPath(); ctx.roundRect(x, H - h, bw, h, 2); ctx.fill()
    })
  }

  drawNeural() {
    if (!this.hasNeuralTarget) return
    const c = this.neuralTarget, ctx = c.getContext("2d"), dp = 2
    c.width = c.offsetWidth * dp; c.height = c.offsetHeight * dp; ctx.scale(dp, dp)
    const W = c.offsetWidth, H = c.offsetHeight
    ctx.clearRect(0, 0, W, H)
    this.nodes.forEach(n => { n.x += n.vx; n.y += n.vy; if (n.x < 0 || n.x > W) n.vx *= -1; if (n.y < 0 || n.y > H) n.vy *= -1 })
    for (let i = 0; i < this.nodes.length; i++) for (let j = i + 1; j < this.nodes.length; j++) {
      const d = Math.hypot(this.nodes[i].x - this.nodes[j].x, this.nodes[i].y - this.nodes[j].y)
      if (d < 90) { ctx.beginPath(); ctx.strokeStyle = `rgba(139,92,246,${0.15 * (1 - d / 90)})`; ctx.lineWidth = 0.8; ctx.moveTo(this.nodes[i].x, this.nodes[i].y); ctx.lineTo(this.nodes[j].x, this.nodes[j].y); ctx.stroke() }
    }
    this.nodes.forEach(n => {
      ctx.beginPath(); ctx.arc(n.x, n.y, 2.5, 0, Math.PI * 2); ctx.fillStyle = "rgba(139,92,246,0.4)"; ctx.fill()
      ctx.beginPath(); ctx.arc(n.x, n.y, 5, 0, Math.PI * 2); ctx.fillStyle = "rgba(139,92,246,0.08)"; ctx.fill()
    })
    this.neuralRaf = requestAnimationFrame(() => this.drawNeural())
  }
}
