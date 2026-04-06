import { Controller } from "@hotwired/stimulus"

// Polls the AI analysis status endpoint and reloads the page when the job finishes.
//
// Usage in view:
//   <div data-controller="ai-analysis-polling"
//        data-ai-analysis-polling-status-url-value="/ai_analysis/123/status">
//
export default class extends Controller {
  static values = {
    statusUrl: String,
    interval: { type: Number, default: 3000 }
  }

  connect() {
    this.pollInterval = setInterval(() => this.poll(), this.intervalValue)
  }

  disconnect() {
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
    }
  }

  poll() {
    fetch(this.statusUrlValue)
      .then(response => response.json())
      .then(data => {
        if (data.status === "running") {
          this.dispatch("running")
        }

        if (data.finished) {
          clearInterval(this.pollInterval)
          window.location.reload()
        }
      })
      .catch(() => {
        // Network error — keep polling
      })
  }
}
