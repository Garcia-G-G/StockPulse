import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step", "progressBar", "stepNum", "selectedStocks", "alertSymbol", "alertMode", "pctPanel", "pricePanel", "pctValue", "alertPrice", "emailInput", "telegramInput", "whatsappInput", "step4Error"]

  connect() {
    this.currentStep = 1
    this.selectedStocks = []
    this.wireAlertMode()
  }

  wireAlertMode() {
    this.element.querySelectorAll('.alert-mode .mode-btn').forEach(btn => {
      btn.addEventListener("click", () => {
        const mode = btn.dataset.mode
        this.element.querySelectorAll('.alert-mode .mode-btn').forEach(b => b.classList.remove("selected"))
        btn.classList.add("selected")
        if (this.hasPctPanelTarget) this.pctPanelTarget.style.display = mode === "pct" ? "block" : "none"
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

  async nextStep(e) {
    e.preventDefault()
    const ok = await this.saveStep(this.currentStep)
    if (!ok) return
    if (this.currentStep < 5) this.showStep(this.currentStep + 1)
  }

  prevStep(e) {
    e.preventDefault()
    if (this.currentStep > 1) this.showStep(this.currentStep - 1)
  }

  skipStep(e) {
    e.preventDefault()
    if (this.currentStep < 5) this.showStep(this.currentStep + 1)
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
    this.progressBarTarget.style.width = `${(step / 5) * 100}%`
    this.stepNumTarget.textContent = step
    this.currentStep = step

    if (step === 3 && this.selectedStocks.length > 0) {
      this.alertSymbolTarget.textContent = this.selectedStocks[0]
    }
  }

  toggleStock(e) {
    e.preventDefault()
    const sym = e.currentTarget.dataset.symbol
    const idx = this.selectedStocks.indexOf(sym)
    if (idx >= 0) {
      this.selectedStocks.splice(idx, 1)
      e.currentTarget.classList.remove("selected")
    } else {
      this.selectedStocks.push(sym)
      e.currentTarget.classList.add("selected")
    }
    this.renderSelected()
  }

  renderSelected() {
    this.selectedStocksTarget.innerHTML = this.selectedStocks.map(s =>
      `<div class="glass-pill"><span>${s}</span><button data-action="click->onboarding#removeStock" data-symbol="${s}">✕</button></div>`
    ).join("")
  }

  removeStock(e) {
    e.preventDefault()
    const sym = e.currentTarget.dataset.symbol
    this.selectedStocks = this.selectedStocks.filter(s => s !== sym)
    this.element.querySelectorAll(".stock-btn").forEach(btn => {
      if (btn.dataset.symbol === sym) btn.classList.remove("selected")
    })
    this.renderSelected()
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
    if (step === 4 && this.hasStep4ErrorTarget) {
      if (messages) {
        this.step4ErrorTarget.textContent = Array.isArray(messages) ? messages.join(" ") : String(messages)
        this.step4ErrorTarget.style.display = "block"
      } else {
        this.step4ErrorTarget.textContent = ""
        this.step4ErrorTarget.style.display = "none"
      }
    }
  }

  getStepData(step) {
    switch (step) {
      case 2: return { symbols: this.selectedStocks }
      case 3: {
        const mode = document.querySelector('input[name="alert-mode"]:checked')?.value || "pct"
        if (mode === "pct") {
          const direction = document.querySelector('input[name="pct-direction"]:checked')?.value || "any"
          const value = this.hasPctValueTarget ? parseFloat(this.pctValueTarget.value || "0") : 0
          return {
            symbol: this.selectedStocks[0],
            alert_type: "price_change_pct",
            condition: { value, direction }
          }
        } else {
          const dir = document.querySelector('input[name="alert-direction"]:checked')?.value
          const price = this.hasAlertPriceTarget ? this.alertPriceTarget.value : ""
          return { symbol: this.selectedStocks[0], condition: { direction: dir, price } }
        }
      }
      case 4: return {
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
    fetch("/onboarding/step/5", {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": token },
      body: JSON.stringify({ data: {} })
    }).then(() => { window.location.href = "/" })
  }
}
