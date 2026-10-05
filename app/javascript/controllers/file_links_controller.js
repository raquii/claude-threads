import { Controller } from "@hotwired/stimulus"

// Browsers won't open file:// from an http page, so file links go through the editor's URL scheme instead.
// The template comes from Settings at click time, which keeps it out of cached message fragments.
export default class extends Controller {
  static values = { template: String }

  open(event) {
    const link = event.target.closest("a.file-link")
    if (!link) return
    event.preventDefault()
    window.location.href = this.templateValue
      .replace("{path}", encodeURI(link.dataset.filePath))
      .replace("{line}", link.dataset.fileLine || "1")
  }
}
