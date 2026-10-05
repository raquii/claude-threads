import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "send"]

  submit(event) {
    event.preventDefault()
    if (this.busy) return
    this.element.requestSubmit()
  }

  start() {
    this.busy = true
    this.sendTarget.disabled = true
  }

  reset(event) {
    this.busy = false
    this.sendTarget.disabled = false
    if (event.detail.success) {
      this.inputTarget.value = ""
      return
    }
    // Refusals come back as a turbo stream with their own message; anything else (a crash, the server down) gets this one.
    const response = event.detail.fetchResponse
    if (!response?.contentType?.includes("turbo-stream")) {
      const status = response ? ` (HTTP ${response.statusCode})` : ""
      document.getElementById("composer_error").textContent = `Couldn't send${status}. Your message is still in the box; try again.`
    }
  }
}
