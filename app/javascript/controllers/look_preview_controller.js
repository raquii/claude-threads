import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  apply(event) {
    document.documentElement.dataset[event.target.dataset.look] = event.target.value
  }
}
