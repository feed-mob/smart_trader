import { Controller } from "@hotwired/stimulus"

// Stimulus controller for asset pages
// Handles chart updates, data loading, and user interactions

export default class extends Controller {
  static targets = ["chart", "price", "change", "volume", "trend", "loading"]

  static values = {
    assetId: Number,
    symbol: String,
    timeframe: { type: String, default: "24h" }
  }

  connect() {
    this.loadAssetData()
    this.setupAutoRefresh()
  }

  disconnect() {
    this.clearAutoRefresh()
  }

  // Load asset data from API
  async loadAssetData() {
    const assetId = this.assetIdValue

    if (!assetId) {
      this.showError("No asset specified")
      return
    }

    this.setLoadingState(true)

    try {
      // Load chart data
      const response = await fetch(`/api/v1/assets/${assetId}/snapshots?timeframe=${this.timeframeValue}`)
      const result = await response.json()

      if (result.success) {
        this.updateChart(result.data)
        this.updatePriceDetails(result.data[0])
      } else {
        this.showError("Failed to load asset data")
      }
    } catch (error) {
      console.error("Error loading asset data:", error)
      this.showError("Network error occurred")
    } finally {
      this.setLoadingState(false)
    }
  }

  // Load AI analysis for asset
  async loadAnalysis() {
    const assetId = this.assetIdValue

    if (!assetId) {
      this.showError("No asset specified")
      return
    }

    this.setLoadingState(true)

    try {
      const response = await fetch(`/api/v1/assets/${assetId}/analyze?hours=48`)
      const result = await response.json()

      if (result.success) {
        this.updateAnalysisUI(result.data)
      } else {
        this.showError(result.error || "Analysis failed")
      }
    } catch (error) {
      console.error("Error loading analysis:", error)
      this.showError("Analysis error occurred")
    } finally {
      this.setLoadingState(false)
    }
  }

  // Update timeframe and reload data
  updateTimeframe(newTimeframe) {
    this.timeframeValue = newTimeframe
    this.loadAssetData()
  }

  // Trigger data collection
  async triggerCollection() {
    try {
      const response = await fetch("/api/v1/assets/collect", {
        method: "POST",
        headers: { "Content-Type": "application/json" }
      })

      const result = await response.json()

      if (result.success) {
        this.showNotification("Data collection started", "success")
      } else {
        this.showError("Failed to trigger collection")
      }
    } catch (error) {
      console.error("Error triggering collection:", error)
      this.showError("Network error occurred")
    }
  }

  // Update chart with new data
  updateChart(data) {
    if (this.hasChartTarget) {
      const chartData = this.prepareChartData(data)
      this.renderChart(chartData)
    }
  }

  // Prepare data for chart rendering
  prepareChartData(snapshots) {
    if (!snapshots || snapshots.length === 0) {
      return { labels: [], prices: [], volumes: [] }
    }

    return {
      labels: snapshots.map(s => this.formatTimestamp(s.captured_at)).reverse(),
      prices: snapshots.map(s => s.price).reverse(),
      volumes: snapshots.map(s => s.volume || 0).reverse(),
      timestamps: snapshots.map(s => s.captured_at).reverse()
    }
  }
  }

  // Format timestamp for display
  formatTimestamp(timestamp) {
    const date = new Date(timestamp)
    return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
  }

  // Render chart (placeholder - integrate with Chart.js)
  renderChart(chartData) {
    // This would integrate with Chart.js or similar library
    // For now, just update a data attribute
    if (this.hasChartTarget) {
      this.chartTarget.dataset.chartData = JSON.stringify(chartData)
      this.dispatchChartEvent("chart:ready", chartData)
    }
  }

  // Dispatch chart event for other controllers to listen
  dispatchChartEvent(name, detail) {
    const event = new CustomEvent(name, { detail })
    window.dispatchEvent(event)
  }

  // Update price display elements
  updatePriceDetails(snapshot) {
    if (this.hasPriceTarget) {
      this.priceTarget.textContent = `$${snapshot.price.toFixed(2)}`
    }

    if (this.hasChangeTarget) {
      const change = snapshot.change_percent || 0
      const sign = change >= 0 ? "+" : ""
      this.changeTarget.textContent = `${sign}${change.toFixed(2)}%`
      this.changeTarget.className = change >= 0 ? "text-green-600" : "text-red-600"
    }

    if (this.hasVolumeTarget) {
      this.volumeTarget.textContent = this.formatVolume(snapshot.volume || 0)
    }
  }

  // Update analysis UI
  updateAnalysisUI(analysis) {
    if (this.hasTrendTarget) {
      this.trendTarget.textContent = this.formatTrend(analysis.trend_direction)
      this.trendTarget.className = this.getTrendClass(analysis.trend_direction)
    }

    // Show signal if available
    if (analysis.trading_signal) {
      const signalClass = this.getSignalClass(analysis.trading_signal)
      const signalElement = document.createElement("div")
      signalElement.className = `inline-block px-3 py-1 rounded-full text-xs font-bold ${signalClass}`
      signalElement.textContent = analysis.trading_signal.toUpperCase()

      if (this.hasTrendTarget) {
        this.trendTarget.appendChild(document.createTextNode(" "))
        this.trendTarget.appendChild(signalElement)
      }
    }
  }

  // Format trend direction
  formatTrend(trend) {
    const trends = {
      bullish: "看涨 ↗",
      bearish: "看跌 ↘",
      neutral: "中性 →"
    }
    return trends[trend] || "未知"
  }

  // Get trend color class
  getTrendClass(trend) {
    const classes = {
      bullish: "text-green-600",
      bearish: "text-red-600",
      neutral: "text-gray-600"
    }
    return classes[trend] || "text-gray-600"
  }

  // Get signal color class
  getSignalClass(signal) {
    const classes = {
      buy: "bg-green-100 text-green-800",
      sell: "bg-red-100 text-red-800",
      hold: "bg-yellow-100 text-yellow-800"
    }
    return classes[signal] || "bg-gray-100 text-gray-800"
  }

  // Format volume with abbreviations
  formatVolume(volume) {
    if (!volume) return "N/A"

    if (volume >= 1000000000) {
      return `${(volume / 1000000000).toFixed(1)}B`
    } else if (volume >= 1000000) {
      return `${(volume / 1000000).toFixed(1)}M`
    } else if (volume >= 1000) {
      return `${(volume / 1000).toFixed(1)}K`
    }
    return volume.toString()
  }

  // Show error message
  showError(message) {
    console.error("Error:", message)

    const errorElement = document.createElement("div")
    errorElement.className = "fixed top-4 right-4 bg-red-500 text-white px-4 py-2 rounded shadow-lg z-50"
    errorElement.textContent = message
    document.body.appendChild(errorElement)

    setTimeout(() => errorElement.remove(), 3000)
  }

  // Show notification
  showNotification(message, type = "info") {
    console.log("Notification:", message)

    const notification = document.createElement("div")
    const colors = {
      success: "bg-green-500",
      info: "bg-blue-500",
      error: "bg-red-500"
    }

    notification.className = `fixed bottom-4 right-4 ${colors[type]} text-white px-4 py-2 rounded shadow-lg z-50`
    notification.textContent = message
    document.body.appendChild(notification)

    setTimeout(() => notification.remove(), 3000)
  }

  // Set loading state
  setLoadingState(isLoading) {
    if (this.hasLoadingTarget) {
      this.loadingTarget.hidden = !isLoading
    }
  }

  // Setup auto refresh (every 5 minutes)
  setupAutoRefresh() {
    this.refreshInterval = setInterval(() => {
      if (document.visibilityState === "visible") {
        this.loadAssetData()
      }
    }, 5 * 60 * 1000)
  }

  // Clear auto refresh
  clearAutoRefresh() {
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval)
    }
  }
}
