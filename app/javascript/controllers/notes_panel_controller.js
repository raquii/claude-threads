import { Controller } from "@hotwired/stimulus"

const OPEN_KEY = "claude-threads:notes-open"
const TAB_KEY = "claude-threads:notes-tab"

// The collapsible notes panel beside a conversation. It also marks messages that have a note: the message
// HTML is cached, so markers and their hover popups are added here from the notes the panel lists.
export default class extends Controller {
  static targets = ["panel", "messageNotes", "newMessageNote", "tab", "pane"]

  connect() {
    try { this.activeTab = localStorage.getItem(TAB_KEY) || "conversation" } catch { this.activeTab = "conversation" }
    this.applyTab()
    this.setOpen(this.storedOpen())
    this.observer = new MutationObserver(() => this.markMessages())
    this.observer.observe(this.element, { childList: true, subtree: true })
    this.markMessages()
  }

  disconnect() {
    this.observer.disconnect()
  }

  toggle() {
    this.setOpen(this.panelTarget.hidden)
  }

  setOpen(open) {
    this.panelTarget.hidden = !open
    this.element.classList.toggle("notes-open", open)
    try { localStorage.setItem(OPEN_KEY, open ? "1" : "0") } catch {}
  }

  storedOpen() {
    try { return localStorage.getItem(OPEN_KEY) === "1" } catch { return false }
  }

  showTab(event) {
    this.selectTab(event.currentTarget.dataset.tab)
  }

  selectTab(name) {
    this.activeTab = name
    try { localStorage.setItem(TAB_KEY, name) } catch {}
    this.applyTab()
  }

  // Saving re-renders the panel body, so the chosen tab is re-applied as its panes reconnect.
  paneTargetConnected() {
    this.applyTab()
  }

  applyTab() {
    // Stimulus can report targets before connect has chosen the tab.
    if (!this.activeTab) return
    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.tab === this.activeTab
      tab.classList.toggle("is-active", active)
      tab.setAttribute("aria-selected", active)
    })
    this.paneTargets.forEach((pane) => (pane.hidden = pane.dataset.tab !== this.activeTab))
  }

  editMessageNote(event) {
    const uuid = event.currentTarget.dataset.messageUuid
    this.setOpen(true)
    this.selectTab("messages")
    let card = this.messageNotesTarget.querySelector(`[data-note-message-uuid="${CSS.escape(uuid)}"]`)
    if (!card) card = this.newCard(uuid, event.currentTarget.closest(".msg"))
    card.scrollIntoView({ block: "nearest" })
    card.querySelector(".note-editor").dispatchEvent(new CustomEvent("note-editor:open"))
  }

  newCard(uuid, message) {
    const card = this.newMessageNoteTarget.content.firstElementChild.cloneNode(true)
    card.dataset.noteMessageUuid = uuid
    card.dataset.unsaved = "true"
    card.querySelector("input[name='note[message_uuid]']").value = uuid
    const fieldId = `note_body_new_${uuid}`
    card.querySelector("textarea").id = fieldId
    card.querySelector("markdown-toolbar").setAttribute("for", fieldId)
    card.querySelector("[data-role=who]").textContent = message.classList.contains("kind-prompt") ? "You" : "Claude"
    card.querySelector("[data-role=snippet]").textContent = message.querySelector(".md")?.textContent.trim().slice(0, 70) || ""
    this.messageNotesTarget.append(card)
    return card
  }

  jump(event) {
    const target = document.getElementById(`message_${event.currentTarget.dataset.messageId}`)
    if (!target) return
    event.preventDefault()
    target.scrollIntoView({ block: "center", behavior: "smooth" })
    target.classList.add("is-target")
    setTimeout(() => target.classList.remove("is-target"), 1600)
  }

  markMessages() {
    this.observer?.disconnect()
    const notes = new Map()
    this.messageNotesTarget.querySelectorAll("[data-note-message-uuid]:not([data-unsaved])").forEach((card) => {
      const body = card.querySelector(".note-body")
      if (body) notes.set(card.dataset.noteMessageUuid, body.innerHTML)
    })
    this.element.querySelectorAll(".note-anchor").forEach((anchor) => {
      const html = notes.get(anchor.querySelector(".note-btn").dataset.messageUuid)
      anchor.classList.toggle("has-note", html !== undefined)
      let popup = anchor.querySelector(".note-popup")
      if (html === undefined) return popup?.remove()
      if (!popup) {
        popup = document.createElement("div")
        popup.className = "note-popup md"
        anchor.append(popup)
      }
      if (popup.innerHTML !== html) popup.innerHTML = html
    })
    this.observer?.observe(this.element, { childList: true, subtree: true })
  }
}
