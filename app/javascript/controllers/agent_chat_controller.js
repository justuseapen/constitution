import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["messages", "input", "response"]
  static values = { conversableType: String, conversableId: Number, url: String }

  connect() {
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      { channel: "AgentChatChannel", conversable_type: this.conversableTypeValue, conversable_id: this.conversableIdValue },
      {
        received: (data) => {
          if (data.type === "delta") {
            this.responseTarget.textContent += data.content
          } else if (data.type === "complete") {
            const msg = document.createElement("div")
            msg.className = "p-3 bg-blue-50 rounded text-sm mb-2"
            msg.textContent = this.responseTarget.textContent
            this.messagesTarget.appendChild(msg)
            this.responseTarget.textContent = ""
          }
        }
      }
    )
  }

  send() {
    const message = this.inputTarget.value
    if (!message.trim()) return

    const userMsg = document.createElement("div")
    userMsg.className = "p-3 bg-gray-100 rounded text-sm mb-2"
    userMsg.textContent = message
    this.messagesTarget.appendChild(userMsg)

    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
      },
      body: JSON.stringify({ message: message })
    })

    this.inputTarget.value = ""
  }

  disconnect() {
    this.subscription?.unsubscribe()
    this.consumer?.disconnect()
  }
}
