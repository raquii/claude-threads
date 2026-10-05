import { Controller } from "@hotwired/stimulus"

// The model, effort, and permission picker next to Send: a <details> panel whose trigger summarizes the choices.
export default class extends Controller {
  static targets = ["summary", "group"]

  connect() {
    this.onOutsideClick = (event) => { if (!this.element.contains(event.target)) this.close() }
    this.onRestore = () => this.ensureChecked()
    this.form = this.element.closest("form")
    document.addEventListener("click", this.onOutsideClick)
    document.addEventListener("turbo:morph", this.onRestore)
    // Capture phase, so it runs before Turbo reads the form's fields.
    this.form.addEventListener("submit", this.onRestore, true)
    this.ensureChecked()
  }

  disconnect() {
    document.removeEventListener("click", this.onOutsideClick)
    document.removeEventListener("turbo:morph", this.onRestore)
    this.form.removeEventListener("submit", this.onRestore, true)
  }

  // A group with nothing checked would send no value at all, so fall back to the session's choice.
  ensureChecked() {
    this.groupTargets.forEach((group) => {
      const radios = Array.from(group.querySelectorAll("input[type=radio]"))
      if (radios.some((radio) => radio.checked)) return
      const fallback = radios.find((radio) => radio.value === group.dataset.default) || radios[0]
      if (fallback) fallback.checked = true
    })
    this.summarize()
  }

  summarize() {
    const parts = Array.from(this.element.querySelectorAll("input[type=radio]:checked"), (input) => input.dataset.summary)
    this.summaryTarget.textContent = parts.filter(Boolean).join(" · ")
  }

  close() {
    if (!this.element.open) return
    this.element.open = false
    this.element.querySelector("summary").focus()
  }
}
