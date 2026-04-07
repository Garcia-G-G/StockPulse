import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step", "progressBar", "stepNum", "selectedStocks", "alertSymbol", "alertPrice", "telegramInput", "whatsappInput"]

  connect() {
    this.currentStep = 1
    this.selectedStocks = []
  }

  nextStep(e) {
    e.preventDefault()
    this.saveStep(this.currentStep)
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

  saveStep(step) {
    const data = this.getStepData(step)
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(`/onboarding/step/${step}`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": token },
      body: JSON.stringify({ data })
    }).catch(console.error)
  }

  getStepData(step) {
    switch (step) {
      case 2: return { symbols: this.selectedStocks }
      case 3: {
        const dir = document.querySelector('input[name="alert-direction"]:checked')?.value
        const price = this.hasAlertPriceTarget ? this.alertPriceTarget.value : ""
        return { symbol: this.selectedStocks[0], condition: { direction: dir, price } }
      }
      case 4: return {
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
