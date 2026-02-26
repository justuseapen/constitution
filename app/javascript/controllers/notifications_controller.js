import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["badge", "dropdown", "list"]
  static values = { url: String, markReadUrl: String }

  connect() {
    this.open = false
    this.loadNotifications()
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      { channel: "NotificationChannel" },
      { received: (data) => { if (data.type === "notification") this.addNotification(data) } }
    )
  }

  toggle() {
    this.open = !this.open
    this.dropdownTarget.classList.toggle("hidden", !this.open)
    if (this.open) this.loadNotifications()
  }

  loadNotifications() {
    fetch(this.urlValue, { headers: { "Accept": "application/json" } })
      .then(r => r.json())
      .then(data => {
        const unread = data.filter(n => !n.read).length
        this.badgeTarget.textContent = unread
        this.badgeTarget.classList.toggle("hidden", unread === 0)
        this.listTarget.innerHTML = data.map(n =>
          `<div class="p-3 text-sm ${n.read ? '' : 'bg-blue-50'}">
            <p>${n.message}</p>
            <p class="text-xs text-gray-400 mt-1">${new Date(n.created_at).toLocaleString()}</p>
          </div>`
        ).join("") || '<p class="p-3 text-sm text-gray-500">No notifications</p>'
      })
  }

  addNotification(data) {
    const count = parseInt(this.badgeTarget.textContent || "0") + 1
    this.badgeTarget.textContent = count
    this.badgeTarget.classList.remove("hidden")
  }

  disconnect() {
    this.subscription?.unsubscribe()
    this.consumer?.disconnect()
  }
}
