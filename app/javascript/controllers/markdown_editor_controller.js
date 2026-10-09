import { Controller } from "@hotwired/stimulus"
import "@github/markdown-toolbar-element"

const SHORTCUTS = { b: "md-bold", i: "md-italic", k: "md-link", e: "md-code" }
// Indent, then a task box, bullet, number, or quote marker.
const LIST_ITEM = /^(\s*)(?:([-*+]) \[[ xX]\] |([-*+]) |(\d+)([.)]) |> )/

// Markdown-aware textarea: ⌘B/⌘I/⌘K/⌘E press the matching toolbar button, Enter continues a list
// (and ends it on an empty item), Tab and Shift-Tab indent list items. Edits go through insertText so ⌘Z still works.
export default class extends Controller {
  static targets = ["input", "toolbar"]

  keydown(event) {
    if (event.isComposing) return
    if ((event.metaKey || event.ctrlKey) && !event.shiftKey && !event.altKey) return this.shortcut(event)
    if (event.key === "Enter" && !event.shiftKey && !event.metaKey && !event.ctrlKey && !event.altKey) return this.continueList(event)
    if (event.key === "Tab" && !event.metaKey && !event.ctrlKey && !event.altKey) return this.indent(event)
  }

  shortcut(event) {
    const tag = SHORTCUTS[event.key.toLowerCase()]
    const button = tag && this.hasToolbarTarget && this.toolbarTarget.querySelector(tag)
    if (!button) return
    event.preventDefault()
    button.click()
  }

  continueList(event) {
    const { line, lineStart, lineEnd } = this.currentLine()
    const match = line.match(LIST_ITEM)
    if (!match || this.inputTarget.selectionStart !== this.inputTarget.selectionEnd) return
    event.preventDefault()

    if (line.slice(match[0].length).trim() === "") {
      this.replace(lineStart, lineEnd, "")
      return
    }
    const [, indent, taskBullet, bullet, number, delimiter] = match
    const marker = taskBullet ? `${taskBullet} [ ] ` : bullet ? `${bullet} ` : number ? `${Number(number) + 1}${delimiter} ` : "> "
    this.insert(`\n${indent}${marker}`)
  }

  indent(event) {
    const { line, lineStart } = this.currentLine()
    if (!LIST_ITEM.test(line)) return
    event.preventDefault()
    const caret = this.inputTarget.selectionStart
    if (event.shiftKey) {
      const removable = line.match(/^ {1,2}/)?.[0].length || 0
      if (removable === 0) return
      this.replace(lineStart, lineStart + removable, "")
      this.inputTarget.setSelectionRange(caret - removable, caret - removable)
    } else {
      this.replace(lineStart, lineStart, "  ")
      this.inputTarget.setSelectionRange(caret + 2, caret + 2)
    }
  }

  currentLine() {
    const { value, selectionStart } = this.inputTarget
    const lineStart = value.lastIndexOf("\n", selectionStart - 1) + 1
    const newline = value.indexOf("\n", selectionStart)
    const lineEnd = newline === -1 ? value.length : newline
    return { line: value.slice(lineStart, lineEnd), lineStart, lineEnd }
  }

  replace(start, end, text) {
    this.inputTarget.setSelectionRange(start, end)
    this.insert(text)
  }

  insert(text) {
    this.inputTarget.focus()
    // execCommand keeps the edit on the undo stack; setRangeText is the fallback where it is unsupported.
    // Inserting "" is unreliable across browsers, so a deletion uses the delete command.
    const done = text === "" ? document.execCommand("delete") : document.execCommand("insertText", false, text)
    if (!done) {
      this.inputTarget.setRangeText(text, this.inputTarget.selectionStart, this.inputTarget.selectionEnd, "end")
      this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    }
  }
}
