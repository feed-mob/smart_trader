import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "content", "list"]
  static values = {
    placeholder: String
  }

  connect() {
    this.files = []
    this.inputTarget.addEventListener("change", this.handleChange.bind(this))
    this.element.addEventListener("dragover", this.handleDragOver.bind(this))
    this.element.addEventListener("dragleave", this.handleDragLeave.bind(this))
    this.element.addEventListener("drop", this.handleDrop.bind(this))
  }

  disconnect() {
    this.inputTarget.removeEventListener("change", this.handleChange.bind(this))
    this.element.removeEventListener("dragover", this.handleDragOver.bind(this))
    this.element.removeEventListener("dragleave", this.handleDragLeave.bind(this))
    this.element.removeEventListener("drop", this.handleDrop.bind(this))
  }

  handleChange(event) {
    this.addFiles(Array.from(event.target.files))
  }

  handleDragOver(event) {
    event.preventDefault()
    this.element.classList.add("is-dragover")
  }

  handleDragLeave(event) {
    event.preventDefault()
    this.element.classList.remove("is-dragover")
  }

  handleDrop(event) {
    event.preventDefault()
    this.element.classList.remove("is-dragover")
    this.addFiles(Array.from(event.dataTransfer.files))
  }

  addFiles(newFiles) {
    const existingNames = new Set(this.files.map(f => f.name))
    newFiles.forEach(file => {
      if (!existingNames.has(file.name)) {
        this.files.push(file)
        existingNames.add(file.name)
      }
    })
    this.syncInputFiles()
    this.renderFileList()
  }

  removeFile(event) {
    event.stopPropagation()
    event.preventDefault()
    const index = parseInt(event.currentTarget.dataset.index)
    this.files.splice(index, 1)
    this.syncInputFiles()
    this.renderFileList()
  }

  syncInputFiles() {
    const dataTransfer = new DataTransfer()
    this.files.forEach(file => dataTransfer.items.add(file))
    this.inputTarget.files = dataTransfer.files
  }

  renderFileList() {
    if (this.files.length === 0) {
      this.element.classList.remove("has-files")
      this.listTarget.innerHTML = ""
      return
    }

    this.element.classList.add("has-files")
    this.listTarget.innerHTML = this.files.map((file, index) => `
      <div class="neural-upload-item">
        <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/>
          <polyline points="14 2 14 8 20 8"/>
        </svg>
        <span class="neural-upload-item__name">${this.escapeHtml(file.name)}</span>
        <span class="neural-upload-item__size">${this.formatSize(file.size)}</span>
        <button type="button" class="neural-upload-item__remove" data-index="${index}" data-action="click->file-upload#removeFile">
          <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="18" y1="6" x2="6" y2="18"/>
            <line x1="6" y1="6" x2="18" y2="18"/>
          </svg>
        </button>
      </div>
    `).join("")
  }

  formatSize(bytes) {
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
