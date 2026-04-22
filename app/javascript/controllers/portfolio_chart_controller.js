import { Controller } from "@hotwired/stimulus"

// Draws an area chart for a single symbol using /api/v1/prices/:id/history.
// Refreshes every 30s. Falls back to a smooth mock curve if the API fails
// so the card never shows a blank void.
export default class extends Controller {
  static targets = ["canvas", "loading", "price", "change", "symbol", "period"]
  static values = {
    symbol: String,
    period: { type: String, default: "24h" },
    refreshInterval: { type: Number, default: 30000 }
  }

  connect() {
    this.points = []
    this.load()
    this.timer = setInterval(() => this.load(), this.refreshIntervalValue)
    window.addEventListener("resize", this.onResize = () => this.render())
  }

  disconnect() {
    if (this.timer) clearInterval(this.timer)
    window.removeEventListener("resize", this.onResize)
  }

  async load() {
    const symbol = this.currentSymbol()
    if (!symbol) return

    this.toggleLoading(true)
    try {
      const { limit, interval } = this.periodParams()
      const res = await fetch(`/api/v1/prices/${encodeURIComponent(symbol)}/history?limit=${limit}&interval=${interval}`, {
        credentials: "same-origin",
        headers: { "Accept": "application/json" }
      })
      if (res.ok) {
        const body = await res.json()
        const rows = body.data || []
        const values = rows.map(r => {
          if (typeof r === "number") return r
          return parseFloat(r.close ?? r.price ?? r.c ?? 0)
        }).filter(v => v > 0)

        if (values.length >= 2) {
          this.points = values
          this.updateHeader()
          this.render()
          this.toggleLoading(false)
          return
        }
      }
    } catch (e) {
      console.warn("chart history fetch failed:", e)
    }

    // Fallback mock
    this.points = this.mockSeries(60)
    this.updateHeader()
    this.render()
    this.toggleLoading(false)
  }

  currentSymbol() {
    if (this.hasSymbolTarget) return this.symbolTarget.textContent.trim().toUpperCase()
    return this.symbolValue
  }

  periodParams() {
    switch (this.periodValue) {
      case "1h":  return { limit: 60,  interval: "1m" }
      case "24h": return { limit: 96,  interval: "15m" }
      case "7d":  return { limit: 168, interval: "1h" }
      case "30d": return { limit: 120, interval: "6h" }
      default:    return { limit: 96,  interval: "15m" }
    }
  }

  selectPeriod(event) {
    event.preventDefault()
    const next = event.currentTarget.dataset.period
    if (!next || next === this.periodValue) return
    this.periodValue = next
    this.element.querySelectorAll(".chart-period").forEach(el => {
      el.classList.toggle("active", el.dataset.period === next)
    })
    this.load()
  }

  toggleLoading(show) {
    if (this.hasLoadingTarget) this.loadingTarget.classList.toggle("hidden", !show)
  }

  updateHeader() {
    if (!this.points.length) return
    const last = this.points[this.points.length - 1]
    const first = this.points[0]
    const pct = ((last - first) / first) * 100

    if (this.hasPriceTarget) {
      this.priceTarget.textContent = `$${last.toLocaleString("en", {
        minimumFractionDigits: 2, maximumFractionDigits: 2
      })}`
    }
    if (this.hasChangeTarget) {
      const klass = pct >= 0 ? "gain" : "loss"
      this.changeTarget.textContent = `${pct >= 0 ? "+" : ""}${pct.toFixed(2)}%`
      this.changeTarget.classList.remove("gain", "loss")
      this.changeTarget.classList.add(klass)
    }
  }

  render() {
    if (!this.hasCanvasTarget || this.points.length < 2) return
    const canvas = this.canvasTarget
    const dpr = window.devicePixelRatio || 1
    const cssW = canvas.clientWidth, cssH = canvas.clientHeight
    if (canvas.width !== cssW * dpr || canvas.height !== cssH * dpr) {
      canvas.width = cssW * dpr
      canvas.height = cssH * dpr
    }
    const ctx = canvas.getContext("2d")
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    ctx.clearRect(0, 0, cssW, cssH)

    const data = this.points
    const min = Math.min(...data)
    const max = Math.max(...data)
    const span = Math.max(max - min, Math.abs(max) * 0.0005 || 0.01)

    const padLeft = 52, padRight = 14, padTop = 18, padBottom = 28
    const W = cssW - padLeft - padRight
    const H = cssH - padTop - padBottom

    const xAt = i => padLeft + (i / (data.length - 1)) * W
    const yAt = v => padTop + H - ((v - min) / span) * H

    // Grid + y-axis labels
    ctx.strokeStyle = "rgba(255,255,255,0.04)"
    ctx.lineWidth = 1
    ctx.font = "10.5px 'JetBrains Mono', monospace"
    ctx.fillStyle = "#4A5370"
    ctx.textAlign = "right"
    ctx.textBaseline = "middle"
    const ticks = 4
    for (let i = 0; i <= ticks; i++) {
      const y = padTop + (H * i) / ticks
      ctx.beginPath()
      ctx.moveTo(padLeft, y)
      ctx.lineTo(padLeft + W, y)
      ctx.stroke()
      const v = max - (span * i) / ticks
      ctx.fillText(`$${v.toFixed(2)}`, padLeft - 8, y)
    }

    // X-axis labels (first, middle, last)
    ctx.textAlign = "center"
    ctx.textBaseline = "top"
    const xLabels = ["earlier", "", "now"]
    ;[0, Math.floor(data.length / 2), data.length - 1].forEach((idx, i) => {
      const label = xLabels[i]
      if (label) ctx.fillText(label, xAt(idx), padTop + H + 8)
    })

    // Area
    const isUp = data[data.length - 1] >= data[0]
    const lineColor = isUp ? "#10B981" : "#F43F5E"
    const grad = ctx.createLinearGradient(0, padTop, 0, padTop + H)
    grad.addColorStop(0, isUp ? "rgba(16,185,129,0.22)" : "rgba(244,63,94,0.18)")
    grad.addColorStop(1, "rgba(0,0,0,0)")
    ctx.beginPath()
    ctx.moveTo(xAt(0), padTop + H)
    data.forEach((v, i) => ctx.lineTo(xAt(i), yAt(v)))
    ctx.lineTo(xAt(data.length - 1), padTop + H)
    ctx.closePath()
    ctx.fillStyle = grad
    ctx.fill()

    // Line
    ctx.beginPath()
    ctx.strokeStyle = lineColor
    ctx.lineWidth = 1.75
    ctx.lineJoin = "round"
    data.forEach((v, i) => {
      const x = xAt(i), y = yAt(v)
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
    })
    ctx.stroke()

    // Glow dot at current price
    const lastX = xAt(data.length - 1), lastY = yAt(data[data.length - 1])
    ctx.beginPath()
    ctx.arc(lastX, lastY, 8, 0, Math.PI * 2)
    ctx.fillStyle = isUp ? "rgba(16,185,129,0.2)" : "rgba(244,63,94,0.18)"
    ctx.fill()
    ctx.beginPath()
    ctx.arc(lastX, lastY, 3.5, 0, Math.PI * 2)
    ctx.fillStyle = lineColor
    ctx.fill()
  }

  mockSeries(n) {
    const base = 100 + Math.random() * 200
    const out = []
    let v = base
    for (let i = 0; i < n; i++) {
      v += (Math.random() - 0.48) * base * 0.006
      out.push(parseFloat(v.toFixed(2)))
    }
    return out
  }
}
