import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop", "input", "results", "error"]

  open(event) {
    event?.preventDefault()
    this.hideError()
    this.backdropTarget.classList.remove("hidden")
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
      this.resultsTarget.innerHTML = ""
      requestAnimationFrame(() => this.inputTarget.focus())
    }
  }

  close(event) {
    event?.preventDefault()
    this.backdropTarget.classList.add("hidden")
  }

  closeIfBackdrop(event) {
    if (event.target === this.backdropTarget) this.close(event)
  }

  async search(event) {
    const query = event.target.value.trim()
    if (query.length < 1) {
      this.resultsTarget.innerHTML = ""
      return
    }

    clearTimeout(this._timer)
    this._timer = setTimeout(async () => {
      try {
        const res = await fetch(`/api/search?q=${encodeURIComponent(query)}`, { credentials: "same-origin" })
        if (!res.ok) return
        const data = await res.json()
        const items = (Array.isArray(data) ? data : data.results || []).slice(0, 8)
        this.resultsTarget.innerHTML = items.length
          ? items.map(r => this.renderResult(r)).join("")
          : `<div class="empty-state" style="padding:18px">No results for "${this.escape(query)}"</div>`
      } catch (e) {
        console.warn("stock search failed:", e)
      }
    }, 160)
  }

  renderResult(r) {
    const sym = (r.symbol || r.s || "").toString()
    const name = (r.name || r.description || "").toString()
    const type = (r.type || "").toString()
    return `<button type="button" class="as-result"
      data-action="click->add-stock-modal#pick"
      data-symbol="${this.escape(sym)}"
      data-name="${this.escape(name)}"
      data-exchange="${this.escape(r.exchange || "")}">
      <span class="sym">${this.escape(sym)}</span>
      <span class="name">${this.escape(name)}</span>
      ${type ? `<span class="type">${this.escape(type)}</span>` : ""}
    </button>`
  }

  escape(s) {
    return String(s).replace(/[&<>"']/g, c => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;"
    }[c]))
  }

  async pick(event) {
    event.preventDefault()
    const btn = event.currentTarget
    const symbol = btn.dataset.symbol
    const name = btn.dataset.name
    const exchange = btn.dataset.exchange

    try {
      const res = await fetch("/api/v1/watchlists", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
        },
        credentials: "same-origin",
        body: JSON.stringify({ watchlist_item: { symbol, name, exchange } })
      })

      if (res.ok || res.status === 201) {
        this.close()
        // Reload to render the new row through ERB.
        window.location.reload()
      } else {
        const body = await res.json().catch(() => ({}))
        this.showError(this.extractError(body) || "Could not add this stock.")
      }
    } catch (e) {
      console.error(e)
      this.showError("Network error. Please try again.")
    }
  }

  extractError(body) {
    if (!body) return null
    if (body.error) return Array.isArray(body.error) ? body.error.join(", ") : body.error
    if (body.errors) return Array.isArray(body.errors) ? body.errors.join(", ") : JSON.stringify(body.errors)
    return null
  }

  showError(msg) {
    if (!this.hasErrorTarget) return alert(msg)
    this.errorTarget.textContent = msg
    this.errorTarget.style.display = "block"
  }

  hideError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = ""
    this.errorTarget.style.display = "none"
  }
}
