// Aurora is now pure CSS — no JavaScript needed.
// This controller is kept as a no-op so existing data-controller attributes don't error.
import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  connect() {}
}
