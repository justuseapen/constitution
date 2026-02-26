import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["list"]
  static values = { documentId: Number }

  connect() {
    this.users = new Map()
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      { channel: "DocumentChannel", document_id: this.documentIdValue },
      {
        received: (data) => {
          if (data.type === "presence") {
            if (data.action === "joined") {
              this.users.set(data.user.id, data.user.name)
            } else {
              this.users.delete(data.user.id)
            }
            this.renderUsers()
          }
        }
      }
    )
  }

  renderUsers() {
    this.listTarget.innerHTML = Array.from(this.users.values())
      .map(name => `<span class="inline-flex items-center px-2 py-1 rounded-full bg-green-100 text-green-800 text-xs">${name}</span>`)
      .join(" ")
  }

  disconnect() {
    this.subscription?.unsubscribe()
    this.consumer?.disconnect()
  }
}
