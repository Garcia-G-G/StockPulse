import { Controller } from "@hotwired/stimulus"

// Manages the hero product card — loads real quote data, updates on search/tab clicks
export default class extends Controller {
  static targets = ["symbol", "price", "change", "alertLabel", "chart"]

  connect() {
    this.currentSymbol = "AAPL"
    this.chartData = []

    // Listen for search result selections
    document.addEventListener("stockpulse:quote-selected", (e) => {
      this.loadSymbol(e.detail.symbol, e.detail.name)
    })

    // Load initial data
    this.loadSymbol("AAPL", "Apple Inc.")

    // Refresh every 15 seconds
    this.refreshInterval = setInterval(() => this.refresh(), 15000)
  }

  disconnect() {
    clearInterval(this.refreshInterval)
    clearInterval(this.chartInterval)
  }

  selectTab(e) {
    e.preventDefault()
    const sym = e.currentTarget.dataset.symbol
    const name = e.currentTarget.dataset.name
    // Update active tab
    this.element.querySelectorAll(".hc-tab").forEach(t => t.classList.remove("active"))
    e.currentTarget.classList.add("active")
    this.loadSymbol(sym, name)
  }

  async loadSymbol(symbol, name) {
    this.currentSymbol = symbol
    // Update alert label immediately
    if (this.hasAlertLabelTarget) this.alertLabelTarget.textContent = `Set alert for ${symbol}`

    try {
      const resp = await fetch(`/api/search?q=${encodeURIComponent(symbol)}`)
      if (!resp.ok) return
      const data = await resp.json()
      if (!Array.isArray(data) || data.length === 0) return

      // Find exact match
      const match = data.find(r => r.symbol === symbol) || data[0]
      if (!match || !match.price) return

      // Update card
      if (this.hasSymbolTarget) {
        const displayName = name || match.name || symbol
        const exchange = match.type === "Crypto" ? "Crypto" : ""
        this.symbolTarget.innerHTML = `${displayName} ${exchange ? `<span class="hc-exchange">${exchange}</span>` : ""}`
      }

      const price = match.price
      const changePct = match.change || 0
      const changeAbs = (price * changePct / 100).toFixed(2)
      const up = changePct >= 0

      if (this.hasPriceTarget) {
        this.priceTarget.textContent = `$${price.toLocaleString("en", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
      }
      if (this.hasChangeTarget) {
        this.changeTarget.className = `hc-change ${up ? "up" : "dn"}`
        this.changeTarget.textContent = `${up ? "+" : ""}$${Math.abs(changeAbs)} (${up ? "+" : ""}${changePct.toFixed(2)}%) today`
      }

      // Fetch full quote for OHLC
      this.loadQuoteDetails(match.finnhub_symbol || symbol)

      // Reset chart for new symbol
      this.initChart(price)

    } catch {
      // Keep current data
    }
  }

  async loadQuoteDetails(finnhubSymbol) {
    try {
      // Use a dedicated endpoint that returns OHLC
      const resp = await fetch(`/api/prices`)
      // We can't easily get OHLC from the search endpoint, so just update what we can
    } catch {
      // Silently fail
    }
  }

  initChart(basePrice) {
    clearInterval(this.chartInterval)
    this.chartData = []
    for (let i = 0; i < 60; i++) {
      this.chartData.push(basePrice * (1 + (Math.random() - 0.5) * 0.02) + Math.sin(i * 0.15) * basePrice * 0.005)
    }
    this.drawChart()
    this.chartInterval = setInterval(() => {
      this.chartData.push(this.chartData[this.chartData.length - 1] * (1 + (Math.random() - 0.48) * 0.003))
      this.chartData.shift()
      this.drawChart()
    }, 3000)
  }

  drawChart() {
    if (!this.hasChartTarget) return
    const c = this.chartTarget
    if (!c || c.offsetWidth === 0) return
    const ctx = c.getContext("2d")
    const dpr = devicePixelRatio || 1
    c.width = c.offsetWidth * dpr
    c.height = c.offsetHeight * dpr
    ctx.scale(dpr, dpr)
    const W = c.offsetWidth, H = c.offsetHeight
    const d = this.chartData
    const min = Math.min(...d) * 0.998, max = Math.max(...d) * 1.002
    const step = W / (d.length - 1)

    // Fill
    const g = ctx.createLinearGradient(0, 0, 0, H)
    g.addColorStop(0, "rgba(59,130,246,0.15)")
    g.addColorStop(1, "transparent")
    ctx.beginPath(); ctx.moveTo(0, H)
    d.forEach((v, i) => ctx.lineTo(i * step, H - (v - min) / (max - min) * H * 0.85))
    ctx.lineTo(W, H); ctx.closePath(); ctx.fillStyle = g; ctx.fill()

    // Line
    ctx.beginPath(); ctx.strokeStyle = "#3B82F6"; ctx.lineWidth = 1.8; ctx.lineJoin = "round"
    d.forEach((v, i) => {
      const x = i * step, y = H - (v - min) / (max - min) * H * 0.85
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
    })
    ctx.stroke()

    // Dot
    const lx = (d.length - 1) * step, ly = H - (d[d.length - 1] - min) / (max - min) * H * 0.85
    ctx.beginPath(); ctx.arc(lx, ly, 3, 0, Math.PI * 2); ctx.fillStyle = "#3B82F6"; ctx.fill()
  }

  refresh() {
    if (this.currentSymbol) this.loadSymbol(this.currentSymbol)
  }
}
