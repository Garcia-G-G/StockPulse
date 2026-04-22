import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { refreshInterval: { type: Number, default: 15000 } }

  connect() {
    this.pollTimer = null
    this.fetchPrices()
    this.startPolling()
  }

  disconnect() {
    if (this.pollTimer) clearInterval(this.pollTimer)
  }

  startPolling() {
    this.pollTimer = setInterval(() => this.fetchPrices(), this.refreshIntervalValue)
  }

  async fetchPrices() {
    const symbols = this.getSymbols()
    if (symbols.length === 0) return

    try {
      const resp = await fetch(`/api/v1/prices/current?symbols=${symbols.join(",")}`, {
        headers: { "Accept": "application/json" },
        credentials: "same-origin"
      })
      if (resp.ok) {
        const body = await resp.json()
        const map = body.data || body
        this.updateAllPrices(map)
        return
      }
    } catch (err) {
      console.warn("Primary price fetch failed, trying landing fallback:", err)
    }

    try {
      const resp = await fetch(`/api/prices`, {
        headers: { "Accept": "application/json" },
        credentials: "same-origin"
      })
      if (!resp.ok) return
      const list = await resp.json()
      if (!Array.isArray(list)) return
      const map = {}
      list.forEach(item => { map[item.s] = { price: item.p, change_percent: item.c } })
      this.updateAllPrices(map)
    } catch (err) {
      console.error("Price fallback also failed:", err)
    }
  }

  updateAllPrices(map) {
    Object.entries(map).forEach(([symbol, info]) => {
      if (info) this.updatePrice(symbol, info)
    })
  }

  updatePrice(symbol, info) {
    const price = info.price ?? info.p
    const change = info.change_percent ?? info.c ?? 0

    document.querySelectorAll(`[data-symbol="${symbol}"][data-field="price"], td.pr[data-symbol="${symbol}"]`).forEach(cell => {
      if (price == null) return
      const prev = cell.textContent
      const formatted = `$${parseFloat(price).toLocaleString("en", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
      if (prev !== formatted) {
        cell.textContent = formatted
        if (prev && prev !== "—") {
          cell.classList.add("price-flash")
          setTimeout(() => cell.classList.remove("price-flash"), 600)
        }
      }
    })

    document.querySelectorAll(`[data-symbol="${symbol}"][data-field="change"]`).forEach(cell => {
      const pct = parseFloat(change)
      if (Number.isNaN(pct)) return
      const isUp = pct >= 0
      cell.textContent = `${isUp ? "+" : ""}${pct.toFixed(2)}%`
      cell.classList.remove("text-gain", "text-loss")
      cell.classList.add(isUp ? "text-gain" : "text-loss")
    })
  }

  getSymbols() {
    const set = new Set()
    this.element.querySelectorAll("[data-symbol]").forEach(el => set.add(el.dataset.symbol))
    return Array.from(set).filter(Boolean)
  }
}
