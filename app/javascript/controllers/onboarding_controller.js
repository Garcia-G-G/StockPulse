import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "step", "progressBar", "stepNum",
    "symbolSearch", "searchResults", "alertSymbol",
    "alertMode", "pctPanel", "pricePanel", "pctValue", "alertPrice",
    "emailInput", "telegramInput", "whatsappInput", "step3Error"
  ]

  static values = { totalSteps: { type: Number, default: 4 } }

  connect() {
    this.currentStep = 1
    this.selectedSymbol = ""
    this.wireAlertMode()
  }

  disconnect() {
    if (this._searchTimer) clearTimeout(this._searchTimer)
  }

  // ----- Alert mode toggle -----

  wireAlertMode() {
    this.element.querySelectorAll(".alert-mode .mode-btn").forEach(btn => {
      btn.addEventListener("click", () => {
        const mode = btn.dataset.mode
        this.element.querySelectorAll(".alert-mode .mode-btn").forEach(b => b.classList.remove("selected"))
        btn.classList.add("selected")
        if (this.hasPctPanelTarget)   this.pctPanelTarget.style.display   = mode === "pct"   ? "block" : "none"
        if (this.hasPricePanelTarget) this.pricePanelTarget.style.display = mode === "price" ? "block" : "none"
      })
    })
  }

  selectPct(e) {
    e.preventDefault()
    const pct = e.currentTarget.dataset.pct
    if (this.hasPctValueTarget) this.pctValueTarget.value = pct
    this.element.querySelectorAll(".pct-pill").forEach(p => p.classList.remove("selected"))
    e.currentTarget.classList.add("selected")
  }

  // ----- Symbol search -----

  searchSymbol(event) {
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
        const items = (Array.isArray(data) ? data : data.results || []).slice(0, 5)
        this.searchResultsTarget.innerHTML = items.map(r => {
          const sym = r.symbol || r.s || ""
          const name = this.escape(r.name || r.description || "")
          return `<button type="button" class="search-result-item" data-action="click->onboarding#pickSymbol" data-symbol="${this.escape(sym)}">
            <span class="sym">${this.escape(sym)}</span><span class="name">${name}</span>
          </button>`
        }).join("")
      } catch (e) {
        console.warn("symbol search failed:", e)
      }
    }, 200)
  }

  pickSymbol(event) {
    event.preventDefault()
    this.selectedSymbol = event.currentTarget.dataset.symbol
    if (this.hasSymbolSearchTarget) this.symbolSearchTarget.value = this.selectedSymbol
    if (this.hasAlertSymbolTarget) this.alertSymbolTarget.textContent = this.selectedSymbol
    this.searchResultsTarget.innerHTML = ""
  }

  escape(s) {
    return String(s).replace(/[&<>"']/g, c => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;"
    }[c]))
  }

  // ----- Step navigation -----

  async nextStep(e) {
    e.preventDefault()
    const ok = await this.saveStep(this.currentStep)
    if (!ok) return
    if (this.currentStep < this.totalStepsValue) this.showStep(this.currentStep + 1)
  }

  prevStep(e) {
    e.preventDefault()
    if (this.currentStep > 1) this.showStep(this.currentStep - 1)
  }

  skipStep(e) {
    e.preventDefault()
    if (this.currentStep < this.totalStepsValue) this.showStep(this.currentStep + 1)
  }

  showStep(step) {
    this.stepTargets.forEach(el => {
      el.classList.remove("active")
      el.style.display = "none"
    })
    const target = this.stepTargets.find(el => el.dataset.step === String(step))
    if (target) {
      target.style.display = "block"
      target.classList.add("active")
    }
    this.progressBarTarget.style.width = `${(step / this.totalStepsValue) * 100}%`
    this.stepNumTarget.textContent = step
    this.currentStep = step
  }

  async saveStep(step) {
    const data = this.getStepData(step)
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    try {
      const resp = await fetch(`/onboarding/step/${step}`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": token, "Accept": "application/json" },
        credentials: "same-origin",
        body: JSON.stringify({ data })
      })
      if (!resp.ok) {
        const body = await resp.json().catch(() => ({}))
        this.showStepError(step, body.errors || [body.error || "Something went wrong."])
        return false
      }
      this.showStepError(step, null)
      return true
    } catch (err) {
      console.error(err)
      this.showStepError(step, ["Network error. Please try again."])
      return false
    }
  }

  showStepError(step, messages) {
    if (step === 3 && this.hasStep3ErrorTarget) {
      if (messages) {
        this.step3ErrorTarget.textContent = Array.isArray(messages) ? messages.join(" ") : String(messages)
        this.step3ErrorTarget.style.display = "block"
      } else {
        this.step3ErrorTarget.textContent = ""
        this.step3ErrorTarget.style.display = "none"
      }
    }
  }

  getStepData(step) {
    switch (step) {
      case 1: return {}
      case 2: {
        const symbol = (this.selectedSymbol || (this.hasSymbolSearchTarget ? this.symbolSearchTarget.value : "")).trim().toUpperCase()
        const mode = document.querySelector('input[name="alert-mode"]:checked')?.value || "pct"
        if (mode === "pct") {
          const direction = document.querySelector('input[name="pct-direction"]:checked')?.value || "any"
          const value = this.hasPctValueTarget ? parseFloat(this.pctValueTarget.value || "0") : 0
          return { symbol, alert_type: "price_change_pct", condition: { value, direction } }
        } else {
          const dir = document.querySelector('input[name="alert-direction"]:checked')?.value
          const price = this.hasAlertPriceTarget ? this.alertPriceTarget.value : ""
          return { symbol, condition: { direction: dir, price } }
        }
      }
      case 3: return {
        email: this.hasEmailInputTarget ? this.emailInputTarget.value : "",
        telegram_chat_id: this.hasTelegramInputTarget ? this.telegramInputTarget.value : "",
        whatsapp_number: this.hasWhatsappInputTarget ? this.whatsappInputTarget.value : ""
      }
      default: return {}
    }
  }

  finish(e) {
    e.preventDefault()
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    fetch("/onboarding/step/4", {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": token },
      body: JSON.stringify({ data: {} })
    }).then(() => { window.location.href = "/" })
  }
}
