import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dot", "label", "time"]

  connect() {
    this.update()
    this.timer = setInterval(() => this.update(), 1000)
  }

  disconnect() {
    if (this.timer) clearInterval(this.timer)
  }

  update() {
    const now = new Date()
    const et = this.toET(now)
    const isOpen = this.isMarketOpen(et)

    if (this.hasDotTarget) {
      this.dotTarget.classList.toggle("open", isOpen)
      this.dotTarget.classList.toggle("closed", !isOpen)
    }
    if (this.hasLabelTarget) {
      this.labelTarget.textContent = isOpen ? "Market Open" : "Market Closed"
    }
    if (this.hasTimeTarget) {
      this.timeTarget.textContent = this.formatTime(et)
    }
  }

  toET(date) {
    const fmt = new Intl.DateTimeFormat("en-US", {
      timeZone: "America/New_York",
      hour12: false, weekday: "short",
      year: "numeric", month: "2-digit", day: "2-digit",
      hour: "2-digit", minute: "2-digit", second: "2-digit"
    })
    const parts = fmt.formatToParts(date).reduce((a, p) => (a[p.type] = p.value, a), {})
    return {
      weekday: parts.weekday,
      hour: parseInt(parts.hour, 10) % 24,
      minute: parseInt(parts.minute, 10),
      second: parseInt(parts.second, 10)
    }
  }

  isMarketOpen(et) {
    const weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri"]
    if (!weekdays.includes(et.weekday)) return false
    const minutes = et.hour * 60 + et.minute
    return minutes >= 570 && minutes < 960 // 9:30 → 16:00 ET
  }

  formatTime(et) {
    const pad = n => String(n).padStart(2, "0")
    return `${pad(et.hour)}:${pad(et.minute)}:${pad(et.second)} ET`
  }
}
