// Feature visuals are now pure CSS animations.
// This controller is kept as a no-op so existing data-controller attributes don't error.
import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  static targets = ["stream", "alerts", "neural"]
  connect() {}
}
