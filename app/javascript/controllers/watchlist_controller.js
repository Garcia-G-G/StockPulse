import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    refreshInterval: { type: Number, default: 30000 },
    sparkPoints: { type: Number, default: 20 }
  }

  connect() {
    this.sparkData = this.restoreSparkData()
    this.fetchAll()
    this.startTimer()

    this._onVisibility = () => {
      if (document.hidden) {
        this.stopTimer()
      } else {
        this.fetchAll()
        this.startTimer()
      }
    }
    document.addEventListener("visibilitychange", this._onVisibility)
  }

  disconnect() {
    this.stopTimer()
    document.removeEventListener("visibilitychange", this._onVisibility)
    this.persistSparkData()
  }

  startTimer() {
    this.stopTimer()
    this.timer = setInterval(() => this.fetchAll(), this.refreshIntervalValue)
  }

  stopTimer() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }

  // ------- Data fetching -------

  async fetchAll() {
    const symbols = this.symbols()
    if (symbols.length === 0) return

    try {
      const res = await fetch(`/api/v1/prices/current?symbols=${encodeURIComponent(symbols.join(","))}`, {
        credentials: "same-origin",
        headers: { "Accept": "application/json" }
      })
      if (res.ok) {
        const body = await res.json()
        const map = body.data || body
        Object.entries(map).forEach(([sym, info]) => {
          if (!info) return
          this.updateSymbol(sym, info.price ?? info.p, info.change_percent ?? info.c)
        })
        this.persistSparkData()
        return
      }
    } catch (e) {
      console.warn("watchlist primary fetch failed:", e)
    }

    // Fallback
    try {
      const res = await fetch(`/api/prices`, { credentials: "same-origin", headers: { "Accept": "application/json" } })
      if (!res.ok) return
      const arr = await res.json()
      if (!Array.isArray(arr)) return
      arr.forEach(item => this.updateSymbol(item.s, item.p, item.c))
      this.persistSparkData()
    } catch (e) {
      console.warn("watchlist fallback failed:", e)
    }
  }

  symbols() {
    const set = new Set()
    this.element.querySelectorAll("[data-wl-symbol]").forEach(el => set.add(el.dataset.wlSymbol))
    return Array.from(set).filter(Boolean)
  }

  // ------- Row updates -------

  updateSymbol(symbol, price, changePct) {
    const row = this.element.querySelector(`[data-wl-symbol="${symbol}"]`)
    if (!row) return

    if (price != null && !Number.isNaN(parseFloat(price))) {
      const priceEl = row.querySelector(".wl-price")
      if (priceEl) {
        const formatted = `$${parseFloat(price).toLocaleString("en", {
          minimumFractionDigits: 2, maximumFractionDigits: 2
        })}`
        const prev = priceEl.textContent
        if (prev !== formatted) {
          priceEl.textContent = formatted
          if (prev && prev !== "—") {
            priceEl.classList.add("flash")
            setTimeout(() => priceEl.classList.remove("flash"), 650)
          }
        }
      }

      if (!this.sparkData[symbol]) this.sparkData[symbol] = []
      this.sparkData[symbol].push(parseFloat(price))
      if (this.sparkData[symbol].length > this.sparkPointsValue) this.sparkData[symbol].shift()
      this.drawSparkline(symbol)
    }

    if (changePct != null && !Number.isNaN(parseFloat(changePct))) {
      const changeEl = row.querySelector(".wl-change")
      if (changeEl) {
        const pct = parseFloat(changePct)
        const klass = pct > 0 ? "gain" : pct < 0 ? "loss" : "neutral"
        const sign = pct > 0 ? "+" : ""
        changeEl.textContent = `${sign}${pct.toFixed(2)}%`
        changeEl.classList.remove("gain", "loss", "neutral")
        changeEl.classList.add(klass)
      }
    }
  }

  // ------- Sparkline -------

  drawSparkline(symbol) {
    const canvas = this.element.querySelector(`canvas[data-spark="${symbol}"]`)
    if (!canvas) return
    const data = this.sparkData[symbol] || []
    if (data.length < 2) return

    const dpr = window.devicePixelRatio || 1
    const cssW = canvas.clientWidth || 120
    const cssH = canvas.clientHeight || 36
    if (canvas.width !== cssW * dpr || canvas.height !== cssH * dpr) {
      canvas.width = cssW * dpr
      canvas.height = cssH * dpr
    }
    const ctx = canvas.getContext("2d")
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    ctx.clearRect(0, 0, cssW, cssH)

    const min = Math.min(...data), max = Math.max(...data)
    const span = Math.max(max - min, Math.abs(max) * 0.001 || 0.001)
    const isUp = data[data.length - 1] >= data[0]
    const color = isUp ? "#10B981" : "#F43F5E"
    const fillColor = isUp ? "rgba(16,185,129,0.15)" : "rgba(244,63,94,0.12)"

    const xAt = i => (i / (data.length - 1)) * (cssW - 2) + 1
    const yAt = v => cssH - ((v - min) / span) * (cssH - 6) - 3

    // Area fill
    const grad = ctx.createLinearGradient(0, 0, 0, cssH)
    grad.addColorStop(0, fillColor)
    grad.addColorStop(1, "rgba(0,0,0,0)")
    ctx.beginPath()
    ctx.moveTo(xAt(0), cssH)
    data.forEach((v, i) => ctx.lineTo(xAt(i), yAt(v)))
    ctx.lineTo(xAt(data.length - 1), cssH)
    ctx.closePath()
    ctx.fillStyle = grad
    ctx.fill()

    // Line
    ctx.beginPath()
    ctx.strokeStyle = color
    ctx.lineWidth = 1.5
    ctx.lineJoin = "round"
    ctx.lineCap = "round"
    data.forEach((v, i) => {
      const x = xAt(i), y = yAt(v)
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
    })
    ctx.stroke()

    // Dot at the end
    const lastX = xAt(data.length - 1), lastY = yAt(data[data.length - 1])
    ctx.beginPath()
    ctx.arc(lastX, lastY, 2, 0, Math.PI * 2)
    ctx.fillStyle = color
    ctx.fill()
  }

  // ------- Spark persistence (session-level cache) -------

  restoreSparkData() {
    try {
      const raw = sessionStorage.getItem("wl_spark")
      if (!raw) return {}
      const parsed = JSON.parse(raw)
      return parsed && typeof parsed === "object" ? parsed : {}
    } catch {
      return {}
    }
  }

  persistSparkData() {
    try {
      sessionStorage.setItem("wl_spark", JSON.stringify(this.sparkData))
    } catch {
      // over-quota or disabled — ignore
    }
  }

  // ------- Row actions -------

  async remove(event) {
    event.preventDefault()
    event.stopPropagation()
    const id = event.currentTarget.dataset.wlId
    if (!id) return
    if (!confirm("Remove this stock from watchlist?")) return

    try {
      const res = await fetch(`/api/v1/watchlists/${id}`, {
        method: "DELETE",
        credentials: "same-origin",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
        }
      })
      if (res.ok || res.status === 204) {
        const row = this.element.querySelector(`[data-wl-id="${id}"]`)
        row?.remove()
      }
    } catch (e) {
      console.error("remove failed", e)
    }
  }

  // Called by add_stock_modal after it has already inserted the row into
  // the panel. Just kick off a fetch so the new row hydrates.
  symbolAdded(event) {
    const { symbol } = event.detail || {}
    if (!symbol) return
    this.fetchAll()
  }
}
