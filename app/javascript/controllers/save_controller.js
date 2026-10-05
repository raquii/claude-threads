import { Controller } from "@hotwired/stimulus"

// A fetch rather than a form, because the button lives inside cached message fragments that must not embed CSRF tokens.
export default class extends Controller {
  static values = { url: String, method: String }

  async toggle(event) {
    event.preventDefault()
    const response = await fetch(this.urlValue, {
      method: this.methodValue,
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]").content
      }
    })
    if (response.ok) window.Turbo.renderStreamMessage(await response.text())
  }
}
