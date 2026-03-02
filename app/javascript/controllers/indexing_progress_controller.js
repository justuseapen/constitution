import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static values = { projectId: Number }

  connect() {
    this.channel = createConsumer().subscriptions.create(
      { channel: "ProjectChannel", project_id: this.projectIdValue },
      {
        received: (data) => {
          if (data.type === "indexing_progress") {
            this.updateRepoStatus(data)
          }
        }
      }
    )
  }

  disconnect() {
    if (this.channel) {
      this.channel.unsubscribe()
    }
  }

  updateRepoStatus(data) {
    const repoEl = document.querySelector(`[data-repo-id="${data.repository_id}"]`)
    if (!repoEl) return

    const statusBadge = repoEl.querySelector("[data-indexing-status]")
    if (statusBadge) {
      statusBadge.textContent = data.progress
      statusBadge.className = this.badgeClass(data.phase)
    }

    if (data.phase === "complete" || data.phase === "failed") {
      // Reload the page to get fresh data after indexing completes
      setTimeout(() => window.location.reload(), 1500)
    }
  }

  badgeClass(phase) {
    const base = "text-xs px-2 py-1 rounded-full"
    switch (phase) {
      case "complete":
        return `${base} bg-green-100 text-green-700`
      case "failed":
        return `${base} bg-red-100 text-red-700`
      default:
        return `${base} bg-blue-100 text-blue-700`
    }
  }
}
