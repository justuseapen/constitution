import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["column"]
  static values = { url: String }

  connect() {
    this.columnTargets.forEach(column => {
      Sortable.create(column, {
        group: "kanban",
        animation: 150,
        onEnd: (event) => {
          const workOrderId = event.item.dataset.workOrderId
          const newStatus = event.to.dataset.status
          const position = event.newIndex

          fetch(this.urlValue.replace(":id", workOrderId), {
            method: "PATCH",
            headers: {
              "Content-Type": "application/json",
              "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
            },
            body: JSON.stringify({
              work_order: { status: newStatus, position: position }
            })
          })
        }
      })
    })
  }
}
