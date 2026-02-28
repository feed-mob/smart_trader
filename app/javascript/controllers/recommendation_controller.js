import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="recommendation"
export default class extends Controller {
  static targets = ["selectedStrategy", "strategyReason"]

  connect() {
    // Wait for the recommendation frame to load
    document.addEventListener("turbo:frame-load", this.handleFrameLoad.bind(this))
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this.handleFrameLoad.bind(this))
  }

  handleFrameLoad(event) {
    if (event.target.id === "recommendation") {
      this.updateStrategiesHighlight()
    }
  }

  updateStrategiesHighlight() {
    const template = this.selectedStrategyTarget
    if (!template) return

    const selectedStrategy = template.content.textContent.trim()
    if (!selectedStrategy) return

    // Update strategies table
    const rows = document.querySelectorAll("[data-strategy-market-condition]")
    rows.forEach(row => {
      const isSelected = row.dataset.strategyMarketCondition === selectedStrategy
      row.classList.toggle("row--highlighted", isSelected)

      // Update status badge
      const statusCell = row.querySelector("td:last-child")
      if (statusCell) {
        if (isSelected) {
          statusCell.innerHTML = '<span class="status-badge status-badge--selected">已选择</span>'
        } else {
          statusCell.innerHTML = ""
        }
      }
    })

    // Move strategy reason to strategies section
    const strategyReason = this.strategyReasonTarget
    if (strategyReason) {
      const strategiesSection = document.querySelector(".preview-section:nth-child(3) .data-table-wrapper")
      if (strategiesSection) {
        const existingReason = strategiesSection.parentElement.querySelector(".strategy-reason:not([style*='display: none'])")
        if (!existingReason) {
          // Clone the element and remove display:none style
          const clone = strategyReason.cloneNode(true)
          clone.style.display = ""
          strategiesSection.insertAdjacentElement("afterend", clone)
        }
      }
    }
  }
}
