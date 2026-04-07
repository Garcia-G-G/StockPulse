import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["body"]

  connect() {
    this.lines = [
      { t: "prompt", v: "> analyze NVDA --depth full" },
      { t: "resp", v: "Scanning 847 data points across 6 timeframes..." },
      { t: "resp", v: "" },
      { t: "hl", v: "▸ Bullish momentum: RSI 67.2, MACD cross confirmed" },
      { t: "hl", v: "▸ Volume 2.3x above 20-day average" },
      { t: "warn", v: "▸ Approaching resistance at $940 — caution" },
      { t: "resp", v: "" },
      { t: "hl", v: "Score: 8.4/10 — Strong buy signal" },
      { t: "resp", v: "Next earnings: May 28. Watch for guidance." }
    ]
    this.shown = false
    this.observer = new IntersectionObserver(entries => {
      if (entries[0].isIntersecting && !this.shown) {
        this.shown = true
        this.typeLines()
      }
    }, { threshold: 0.25 })
    this.observer.observe(this.bodyTarget)
  }

  disconnect() { this.observer?.disconnect() }

  typeLines() {
    let i = 0
    const add = () => {
      if (i >= this.lines.length) return
      const l = this.lines[i]
      const div = document.createElement("div")
      div.className = "ai-line"
      const cls = l.t === "prompt" ? "ai-prompt" : l.t === "hl" ? "ai-hl" : l.t === "warn" ? "ai-warn" : "ai-resp"
      div.innerHTML = `<span class="${cls}">${l.v || "&nbsp;"}</span>`
      if (i === this.lines.length - 1) div.innerHTML += '<span class="ai-cursor"></span>'
      this.bodyTarget.appendChild(div)
      setTimeout(() => div.classList.add("vis"), 40)
      i++
      setTimeout(add, 250 + Math.random() * 350)
    }
    add()
  }
}
