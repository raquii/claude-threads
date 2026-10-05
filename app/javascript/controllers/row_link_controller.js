import { Controller } from "@hotwired/stimulus"

// Makes a block clickable without wrapping it in <a>, so links inside it keep working.
export default class extends Controller {
  static values = { url: String }

  visit(event) {
    if (event.target.closest("a, button") || window.getSelection().toString()) return
    if (event.metaKey || event.ctrlKey) return window.open(this.urlValue, "_blank")
    window.Turbo.visit(this.urlValue)
  }
}
