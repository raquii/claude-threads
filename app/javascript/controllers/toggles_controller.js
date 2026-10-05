import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "claude-threads:toggles"

// A box with data-toggle-parent is disabled while its parent is off; it keeps its own checked state for when the parent returns.
export default class extends Controller {
  static targets = ["box"]

  connect() {
    const saved = this.load()
    this.boxTargets.forEach((box) => {
      const name = box.dataset.toggle
      box.checked = name in saved ? saved[name] === true : box.dataset.toggleDefault === "true"
      this.apply(box)
    })
    this.syncChildren()
  }

  change(event) {
    this.apply(event.target)
    this.syncChildren()
    const saved = this.load()
    saved[event.target.dataset.toggle] = event.target.checked
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(saved)) } catch {}
  }

  apply(box) {
    this.element.classList.toggle(`show-${box.dataset.toggle}`, box.checked)
  }

  syncChildren() {
    this.boxTargets.filter((box) => box.dataset.toggleParent).forEach((box) => {
      const parent = this.boxTargets.find((b) => b.dataset.toggle === box.dataset.toggleParent)
      box.disabled = !parent.checked
      box.closest("label").classList.toggle("is-disabled", box.disabled)
    })
  }

  load() {
    try { return JSON.parse(localStorage.getItem(STORAGE_KEY)) || {} } catch { return {} }
  }
}
