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
    if (event.detail.success) this.inputTarget.value = ""
  }
}
