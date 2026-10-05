import { Controller } from "@hotwired/stimulus"

const GROUP_STATE_COOKIE = "sidebar_groups"

// Reloads the sidebar frame on an interval; group open/closed state goes to a cookie the server renders from.
export default class extends Controller {
  static targets = ["frame"]
  static values = { interval: Number }

  connect() {
    this.timer = setInterval(() => { if (!document.hidden) this.frameTarget.reload() }, this.intervalValue)
    this.onClick = (event) => this.remember(event)
    this.element.addEventListener("click", this.onClick)
  }

  disconnect() {
    clearInterval(this.timer)
    this.element.removeEventListener("click", this.onClick)
  }

  // Listens for clicks rather than toggle events, which also fire when a reload inserts an open group.
  remember(event) {
    const details = event.target.closest("summary")?.parentElement
    if (!details?.matches("details.project[data-key]")) return
    setTimeout(() => {
      const state = this.groupState()
      state[details.dataset.key] = details.open
      document.cookie = `${GROUP_STATE_COOKIE}=${encodeURIComponent(JSON.stringify(state))}; path=/; max-age=31536000; samesite=lax`
    })
  }

  groupState() {
    const raw = document.cookie.split("; ").find((c) => c.startsWith(`${GROUP_STATE_COOKIE}=`))
    try { return JSON.parse(decodeURIComponent(raw.split("=")[1])) || {} } catch { return {} }
  }
}
