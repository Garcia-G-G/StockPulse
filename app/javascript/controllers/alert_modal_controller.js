import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "form", "symbolInput", "searchResults", "title", "submit", "error"]

  connect() {
    this.wireChannelCards()
    this.wireDirectionRadios()
  }

  // --- Open / close ---

  async open(event) {
    event?.preventDefault()
    const alertId = event?.currentTarget?.dataset?.alertId
    this.resetForm()
    this.hideError()

    if (alertId) {
      this.titleTarget.textContent = "Edit alert"
      this.submitTarget.textContent = "Save Changes"
      this.formTarget.dataset.alertId = alertId
      await this.loadAlert(alertId)
    } else {
      this.titleTarget.textContent = "Create alert"
      this.submitTarget.textContent = "Create Alert"
      this.formTarget.dataset.alertId = ""
    }

    this.modalTarget.classList.remove("hidden")
  }

  close(event) {
    event?.preventDefault()
    this.modalTarget.classList.add("hidden")
  }

  closeIfBackdrop(event) {
    if (event.target === this.modalTarget) this.close(event)
  }

  // --- Alert type cards ---

  selectType(event) {
    event.preventDefault()
    const type = event.currentTarget.dataset.type
    this.element.querySelectorAll("[data-type-card]").forEach(c => c.classList.remove("selected"))
    event.currentTarget.classList.add("selected")
    this.showConditionFor(type)
  }

  showConditionFor(type) {
    this.element.querySelectorAll("[data-condition-panel]").forEach(p => p.classList.remove("active"))
    const panel = this.element.querySelector(`[data-condition-panel="${type}"]`)
    if (panel) panel.classList.add("active")
  }

  // --- Quick pills ---

  selectPercentage(event) {
    event.preventDefault()
    const pct = event.currentTarget.dataset.pct
    const input = document.getElementById("pct-value")
    if (input) input.value = pct
    this.markPillSelected(event.currentTarget, "[data-pct]")
  }

  selectMultiplier(event) {
    event.preventDefault()
    const mult = event.currentTarget.dataset.mult
    const input = document.getElementById("volume-value")
    if (input) input.value = mult
    this.markPillSelected(event.currentTarget, "[data-mult]")
  }

  markPillSelected(selected, selector) {
    this.element.querySelectorAll(`.pill${selector}`).forEach(p => p.classList.remove("selected"))
    selected.classList.add("selected")
  }

  // --- Symbol search ---

  async searchSymbol(event) {
    const query = event.target.value.trim()
    if (query.length < 1) {
      this.searchResultsTarget.innerHTML = ""
      return
    }

    clearTimeout(this._searchTimer)
    this._searchTimer = setTimeout(async () => {
      try {
        const res = await fetch(`/api/search?q=${encodeURIComponent(query)}`, { credentials: "same-origin" })
        if (!res.ok) return
        const data = await res.json()
        const items = (Array.isArray(data) ? data : data.results || []).slice(0, 6)
        this.searchResultsTarget.innerHTML = items.map(r => {
          const sym = r.symbol || r.s || ""
          const name = r.name || r.description || ""
          return `<button type="button" class="search-result-item" data-action="click->alert-modal#pickSymbol" data-symbol="${sym}">
            <span class="sym">${sym}</span><span class="name">${name}</span>
          </button>`
        }).join("")
      } catch (e) {
        console.warn("symbol search failed:", e)
      }
    }, 180)
  }

  pickSymbol(event) {
    event.preventDefault()
    this.symbolInputTarget.value = event.currentTarget.dataset.symbol
    this.searchResultsTarget.innerHTML = ""
  }

  // --- Channel cards (visual toggle) ---

  wireChannelCards() {
    this.element.querySelectorAll("[data-channel-card]").forEach(card => {
      if (card.classList.contains("disabled")) return
      const input = card.querySelector("input[type=checkbox]")
      if (!input) return
      const sync = () => card.classList.toggle("selected", input.checked)
      sync()
      card.addEventListener("click", e => {
        if (e.target.tagName === "A") return
        e.preventDefault()
        input.checked = !input.checked
        sync()
      })
    })
  }

  wireDirectionRadios() {
    this.element.querySelectorAll(".dir-btn input[type=radio]").forEach(radio => {
      radio.addEventListener("change", () => {
        const group = radio.name
        this.element.querySelectorAll(`.dir-btn input[name='${group}']`).forEach(r => {
          r.closest(".dir-btn").classList.toggle("selected", r.checked)
        })
      })
    })
  }

  // --- Submit ---

  async submit(event) {
    event.preventDefault()
    this.hideError()

    const symbol = this.symbolInputTarget.value.trim().toUpperCase()
    const alertType = this.element.querySelector("[data-type-card].selected")?.dataset.type

    if (!symbol) return this.showError("Please enter a symbol.")
    if (!alertType) return this.showError("Please pick an alert type.")

    const condition = this.getCondition(alertType)
    if (!this.validateCondition(alertType, condition)) return

    const channels = this.getChannels()
    const cooldown = parseInt(document.getElementById("cooldown-select")?.value || "15", 10)

    const body = {
      alert: {
        symbol,
        alert_type: alertType,
        condition,
        notification_channels: channels,
        cooldown_minutes: cooldown,
        active: true
      }
    }

    const alertId = this.formTarget.dataset.alertId
    const url = alertId ? `/api/v1/alerts/${alertId}` : "/api/v1/alerts"
    const method = alertId ? "PATCH" : "POST"

    try {
      const res = await fetch(url, {
        method,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
        },
        credentials: "same-origin",
        body: JSON.stringify(body)
      })

      if (res.ok) {
        window.location.reload()
      } else {
        const err = await res.json().catch(() => ({}))
        this.showError(err.error || "Failed to save alert")
      }
    } catch (e) {
      console.error(e)
      this.showError("Network error. Please try again.")
    }
  }

  getCondition(type) {
    switch (type) {
      case "price_above":
        return { value: parseFloat(document.getElementById("price-value")?.value || 0) }
      case "price_below":
        return { value: parseFloat(document.getElementById("price-below-value")?.value || 0) }
      case "price_change_pct":
        return {
          value: parseFloat(document.getElementById("pct-value")?.value || 0),
          direction: document.querySelector('input[name="pct-direction"]:checked')?.value || "any"
        }
      case "volume_spike":
        return { value: parseFloat(document.getElementById("volume-value")?.value || 0) }
      default:
        return {}
    }
  }

  validateCondition(type, condition) {
    if (!(condition.value > 0)) {
      this.showError("Please enter a valid numeric value.")
      return false
    }
    if (type === "price_change_pct" && !["up", "down", "any"].includes(condition.direction)) {
      this.showError("Please pick a direction.")
      return false
    }
    return true
  }

  getChannels() {
    const channels = []
    if (document.getElementById("ch-email")?.checked) channels.push("email")
    const tg = document.getElementById("ch-telegram")
    if (tg?.checked && !tg.disabled) channels.push("telegram")
    const wa = document.getElementById("ch-whatsapp")
    if (wa?.checked && !wa.disabled) channels.push("whatsapp")
    return channels.length > 0 ? channels : ["email"]
  }

  showError(msg) {
    this.errorTarget.textContent = msg
    this.errorTarget.style.display = "block"
  }

  hideError() {
    this.errorTarget.textContent = ""
    this.errorTarget.style.display = "none"
  }

  // --- Toggle / delete ---

  async toggleAlert(event) {
    const id = event.currentTarget.dataset.alertId
    try {
      const res = await fetch(`/api/v1/alerts/${id}/toggle`, {
        method: "PATCH",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
        },
        credentials: "same-origin"
      })
      if (!res.ok) {
        event.currentTarget.checked = !event.currentTarget.checked
      }
    } catch (e) {
      event.currentTarget.checked = !event.currentTarget.checked
    }
  }

  async deleteAlert(event) {
    event.preventDefault()
    if (!confirm("Delete this alert?")) return
    const id = event.currentTarget.dataset.alertId
    try {
      const res = await fetch(`/api/v1/alerts/${id}`, {
        method: "DELETE",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
        },
        credentials: "same-origin"
      })
      if (res.ok) {
        const row = this.element.querySelector(`.alert-row[data-alert-id="${id}"]`)
        row?.remove()
      }
    } catch (e) {
      console.error(e)
    }
  }

  // --- Reset / load existing ---

  resetForm() {
    this.symbolInputTarget.value = ""
    this.searchResultsTarget.innerHTML = ""
    this.element.querySelectorAll("[data-type-card]").forEach(c => c.classList.remove("selected"))
    this.element.querySelectorAll("[data-condition-panel]").forEach(p => p.classList.remove("active"))
    this.element.querySelectorAll(".pill").forEach(p => p.classList.remove("selected"))
    ;["price-value", "price-below-value", "pct-value", "volume-value"].forEach(id => {
      const el = document.getElementById(id)
      if (el) el.value = ""
    })
    const anyRadio = this.element.querySelector('input[name="pct-direction"][value="any"]')
    if (anyRadio) {
      anyRadio.checked = true
      this.element.querySelectorAll(".dir-btn").forEach(b => b.classList.remove("selected"))
      anyRadio.closest(".dir-btn")?.classList.add("selected")
    }
    const cd = document.getElementById("cooldown-select")
    if (cd) cd.value = "15"

    // Reset channel cards: email on, telegram/whatsapp off
    const emailInput = document.getElementById("ch-email")
    if (emailInput) emailInput.checked = true
    ;["ch-telegram", "ch-whatsapp"].forEach(id => {
      const el = document.getElementById(id)
      if (el) el.checked = false
    })
    this.element.querySelectorAll("[data-channel-card]").forEach(card => {
      const input = card.querySelector("input[type=checkbox]")
      if (input) card.classList.toggle("selected", input.checked)
    })
  }

  async loadAlert(id) {
    try {
      const res = await fetch(`/api/v1/alerts/${id}`, {
        headers: { "Accept": "application/json" },
        credentials: "same-origin"
      })
      if (!res.ok) return
      const alert = await res.json()

      this.symbolInputTarget.value = alert.symbol || ""

      // Select type card
      const typeCard = this.element.querySelector(`[data-type-card][data-type="${alert.alert_type}"]`)
      if (typeCard) {
        typeCard.classList.add("selected")
        this.showConditionFor(alert.alert_type)
      }

      const cond = alert.condition || {}
      const value = cond.value ?? cond["value"] ?? ""
      switch (alert.alert_type) {
        case "price_above":
          document.getElementById("price-value").value = value
          break
        case "price_below":
          document.getElementById("price-below-value").value = value
          break
        case "price_change_pct":
          document.getElementById("pct-value").value = value
          const dir = cond.direction || cond["direction"] || "any"
          const radio = this.element.querySelector(`input[name="pct-direction"][value="${dir}"]`)
          if (radio) {
            radio.checked = true
            this.element.querySelectorAll(".dir-btn").forEach(b => b.classList.remove("selected"))
            radio.closest(".dir-btn")?.classList.add("selected")
          }
          break
        case "volume_spike":
          document.getElementById("volume-value").value = value
          break
      }

      // Channels
      const channels = alert.notification_channels || []
      const emailInput = document.getElementById("ch-email")
      if (emailInput) emailInput.checked = channels.includes("email")
      ;[["ch-telegram", "telegram"], ["ch-whatsapp", "whatsapp"]].forEach(([id, name]) => {
        const el = document.getElementById(id)
        if (el && !el.disabled) el.checked = channels.includes(name)
      })
      this.element.querySelectorAll("[data-channel-card]").forEach(card => {
        const input = card.querySelector("input[type=checkbox]")
        if (input) card.classList.toggle("selected", input.checked)
      })

      // Cooldown
      const cd = document.getElementById("cooldown-select")
      if (cd) cd.value = String(alert.cooldown_minutes || 15)
    } catch (e) {
      console.error("failed to load alert", e)
    }
  }
}
