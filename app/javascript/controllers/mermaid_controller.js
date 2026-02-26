import { Controller } from "@hotwired/stimulus"
import mermaid from "mermaid"

export default class extends Controller {
  static targets = ["source", "preview"]

  connect() {
    mermaid.initialize({ startOnLoad: false, theme: "default" })
    this.render()
  }

  render() {
    const code = this.sourceTarget.textContent
    mermaid.render("mermaid-preview", code).then(({ svg }) => {
      this.previewTarget.innerHTML = svg
    })
  }
}
