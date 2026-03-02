import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["log", "status", "prLink"]
  static values = { executionId: Number, status: String }

  connect() {
    if (this.statusValue === "queued" || this.statusValue === "running") {
      this.setupActionCable()
    }
    this.scrollToBottom()
  }

  setupActionCable() {
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      {
        channel: "WorkOrderExecutionChannel",
        execution_id: this.executionIdValue
      },
      { received: (data) => this.handleReceived(data) }
    )
  }

  handleReceived(data) {
    if (data.type === "log") {
      this.appendLog(data.content)
    } else if (data.type === "complete") {
      this.updateStatus(data.status)
      this.subscription?.unsubscribe()
    } else if (data.type === "error") {
      this.appendLog(`ERROR: ${data.content}\n`)
    }
  }

  appendLog(text) {
    if (this.hasLogTarget) {
      this.logTarget.textContent += text
      this.scrollToBottom()
    }
  }

  updateStatus(status) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = status.charAt(0).toUpperCase() + status.slice(1)
      this.statusTarget.className = status === "completed"
        ? "px-2 py-1 rounded text-xs font-medium bg-green-100 text-green-800"
        : "px-2 py-1 rounded text-xs font-medium bg-red-100 text-red-800"
    }
    setTimeout(() => window.location.reload(), 2000)
  }

  scrollToBottom() {
    if (this.hasLogTarget) {
      this.logTarget.scrollTop = this.logTarget.scrollHeight
    }
  }

  disconnect() {
    this.subscription?.unsubscribe()
    this.consumer?.disconnect()
  }
}
