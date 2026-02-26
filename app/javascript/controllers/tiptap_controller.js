import { Controller } from "@hotwired/stimulus"
import { Editor } from "@tiptap/core"
import StarterKit from "@tiptap/starter-kit"
import Placeholder from "@tiptap/extension-placeholder"

export default class extends Controller {
  static targets = ["editor", "input"]
  static values = { content: String }

  connect() {
    this.editor = new Editor({
      element: this.editorTarget,
      extensions: [
        StarterKit,
        Placeholder.configure({
          placeholder: "Start writing..."
        })
      ],
      content: this.contentValue || "",
      onUpdate: ({ editor }) => {
        this.inputTarget.value = editor.getHTML()
      }
    })
  }

  disconnect() {
    this.editor.destroy()
  }
}
