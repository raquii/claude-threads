import { Controller } from "@hotwired/stimulus"

const IDLE_INTERVAL = 2500
const ACTIVE_INTERVAL = 1000
const HIDDEN_INTERVAL = 15000
const STICK_THRESHOLD = 120
const MIN_GROUP_SIZE = 2
const GROUPABLE = ".kind-tool_use, .kind-thinking, .kind-meta, .sidechain, .tool-group"

export default class extends Controller {
  static targets = ["scroller", "messages"]
  static values = { pollUrl: String, targetId: String, generation: String }

  connect() {
    this.observer = new MutationObserver((records) => this.onMutation(records))
    this.groupTools()
    const target = this.targetIdValue && document.getElementById(`message_${this.targetIdValue}`)
    if (target) {
      target.classList.add("is-target")
      target.scrollIntoView({ block: "center" })
    } else {
      this.scrollToBottom()
    }
    this.schedule()
  }

  disconnect() {
    clearTimeout(this.timer)
    this.abort?.abort()
    this.observer.disconnect()
  }

  schedule() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.poll(), this.interval())
  }

  interval() {
    if (document.hidden) return HIDDEN_INTERVAL
    return document.querySelector("#run_status [data-active='true']") ? ACTIVE_INTERVAL : IDLE_INTERVAL
  }

  async poll() {
    const url = new URL(this.pollUrlValue, window.location.origin)
    url.searchParams.set("after", this.lastMessageId())
    url.searchParams.set("generation", this.generationValue)
    this.abort = new AbortController()
    try {
      const response = await fetch(url, { headers: { Accept: "text/vnd.turbo-stream.html" }, signal: this.abort.signal })
      if (response.ok) {
        this.stickAfterRender = this.nearBottom()
        window.Turbo.renderStreamMessage(await response.text())
      }
    } catch (error) {
      if (error.name === "AbortError") return
    }
    this.schedule()
  }

  // Tool chips move into groups, so the newest id isn't necessarily the last direct child.
  lastMessageId() {
    let max = 0
    this.messagesTarget.querySelectorAll("[data-message-id]").forEach((el) => {
      if (el.closest(".messages") === this.messagesTarget) max = Math.max(max, Number(el.dataset.messageId))
    })
    return String(max)
  }

  nearBottom() {
    const s = this.scrollerTarget
    return s.scrollHeight - s.scrollTop - s.clientHeight < STICK_THRESHOLD
  }

  scrollToBottom() {
    this.scrollerTarget.scrollTop = this.scrollerTarget.scrollHeight
  }

  // Older pages render above the viewport; keep the reader's position fixed while they grow the list.
  // Frame render events bubble, so a tool call expanding inside an older page must not trigger this.
  preserveScroll(event) {
    if (event.target !== event.currentTarget) return
    const scroller = this.scrollerTarget
    const before = scroller.scrollHeight
    const render = event.detail.render
    event.detail.render = async (current, next) => {
      await render(current, next)
      this.groupTools()
      scroller.scrollTop += scroller.scrollHeight - before
    }
  }

  onMutation(records) {
    if (records.every((record) => record.target.closest?.("details.tool"))) return
    this.groupTools()
    if (this.stickAfterRender) {
      this.stickAfterRender = false
      this.scrollToBottom()
    }
  }

  // Idempotent: re-runs after every append and older page so runs split across loads merge.
  groupTools() {
    this.observer.disconnect()
    let run = []
    const flush = () => {
      if (this.toolCount(run) >= MIN_GROUP_SIZE) this.mergeRun(run)
      run = []
    }
    this.topLevelItems().forEach((item) => (item.matches(GROUPABLE) ? run.push(item) : flush()))
    flush()
    this.observer.observe(this.messagesTarget, { childList: true, subtree: true })
  }

  topLevelItems() {
    return Array.from(this.messagesTarget.querySelectorAll(".msg, .tool-group")).filter(
      (el) => el.parentElement.closest(".messages, .tool-group") === this.messagesTarget
    )
  }

  toolCount(items) {
    return items.reduce((sum, el) => {
      if (el.classList.contains("tool-group")) return sum + el.querySelectorAll(":scope > .tool-group-body > .kind-tool_use").length
      return sum + (el.classList.contains("kind-tool_use") ? 1 : 0)
    }, 0)
  }

  mergeRun(run) {
    let group = run.find((el) => el.classList.contains("tool-group"))
    if (!group) {
      group = document.createElement("details")
      group.className = "tool-group"
      group.innerHTML = `<summary><span class="tool-group-label"></span><span class="tool-group-names"></span></summary><div class="tool-group-body"></div>`
    }
    if (group !== run[0]) run[0].before(group)

    const body = group.querySelector(".tool-group-body")
    const leaves = run.flatMap((el) => (el.classList.contains("tool-group") ? Array.from(el.querySelector(".tool-group-body").children) : [el]))
    body.append(...leaves)
    run.forEach((el) => { if (el !== group && el.classList.contains("tool-group")) el.remove() })

    const tools = Array.from(body.querySelectorAll(":scope > .kind-tool_use .tool-name"), (el) => el.textContent)
    const counts = new Map()
    tools.forEach((name) => counts.set(name, (counts.get(name) || 0) + 1))
    group.querySelector(".tool-group-label").textContent = `${tools.length} tool calls`
    group.querySelector(".tool-group-names").textContent = Array.from(counts, ([name, n]) => (n > 1 ? `${name} ×${n}` : name)).join(" · ")
  }
}
