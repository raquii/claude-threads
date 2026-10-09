import { Controller } from "@hotwired/stimulus"

// Write/Preview editor for a note; saving submits the form, and the server re-renders the whole panel.
export default class extends Controller {
  static targets = ["view", "form", "input", "writeTab", "previewTab", "previewPane"]
  static values = { previewUrl: String }

  edit() {
    this.viewTarget.hidden = true
    this.formTarget.hidden = false
    this.write()
    this.inputTarget.focus()
    this.inputTarget.setSelectionRange(this.inputTarget.value.length, this.inputTarget.value.length)
  }

  cancel() {
    // A message note that was never saved has no view to return to.
    const card = this.element.closest(".message-note")
    if (card?.dataset.unsaved) return card.remove()
    this.formTarget.hidden = true
    this.viewTarget.hidden = false
  }

  save(event) {
    event.preventDefault()
    this.formTarget.requestSubmit()
  }

  delete() {
    if (!confirm("Delete this note?")) return
    this.inputTarget.value = ""
    this.formTarget.requestSubmit()
  }

  write() {
    this.inputTarget.hidden = false
    this.previewPaneTarget.hidden = true
    this.writeTabTarget.classList.add("is-active")
    this.previewTabTarget.classList.remove("is-active")
  }

  async preview() {
    const response = await fetch(this.previewUrlValue, {
      method: "POST",
      headers: { "X-CSRF-Token": document.querySelector("meta[name=csrf-token]").content },
      body: new URLSearchParams({ body: this.inputTarget.value })
    })
    this.previewPaneTarget.innerHTML = response.ok ? await response.text() : "<p>Preview failed.</p>"
    this.inputTarget.hidden = true
    this.previewPaneTarget.hidden = false
    this.previewTabTarget.classList.add("is-active")
    this.writeTabTarget.classList.remove("is-active")
  }
}
