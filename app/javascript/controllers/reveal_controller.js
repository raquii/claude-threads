import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["shown", "hidden"]

  toggle() {
    this.shownTargets.forEach((el) => (el.hidden = !el.hidden))
    this.hiddenTargets.forEach((el) => {
      el.hidden = !el.hidden
      if (!el.hidden) el.querySelector("input[type=text]")?.select()
    })
  }
}
