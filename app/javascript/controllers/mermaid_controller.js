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
    const id = `mermaid-${Math.random().toString(36).substring(2, 9)}`
    mermaid.render(id, code).then(({ svg }) => {
      this.previewTarget.innerHTML = svg
    }).catch((error) => {
      this.previewTarget.innerHTML = `<p class="text-sm text-red-500">Diagram rendering failed: ${error.message}</p>`
    })
  }
}
