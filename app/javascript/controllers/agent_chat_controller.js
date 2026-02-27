import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"
import { parser, default_renderer } from "streaming-markdown"
import hljs from "highlight.js"

export default class extends Controller {
  static targets = ["messages", "input", "response", "responseWrapper", "loading", "resizer", "sidebar"]
  static values = { conversableType: String, conversableId: Number, url: String }

  connect() {
    this.isStreaming = false
    this.userScrolledUp = false
    this.loadHistory()
    this.setupActionCable()
    this.setupResize()
    this.setupScrollDetection()
  }

  // --- ActionCable ---

  setupActionCable() {
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      {
        channel: "AgentChatChannel",
        conversable_type: this.conversableTypeValue,
        conversable_id: this.conversableIdValue
      },
      { received: (data) => this.handleReceived(data) }
    )
  }

  handleReceived(data) {
    if (data.type === "delta") {
      if (!this.isStreaming) {
        this.isStreaming = true
        this.hideLoading()
        this.showResponseWrapper()
        this.smdRenderer = default_renderer(this.responseTarget)
        this.smdParser = parser(this.smdRenderer)
      }
      this.smdParser.write(data.content)
      this.autoScroll()
    } else if (data.type === "complete") {
      this.finalizeResponse()
    } else if (data.type === "error") {
      this.hideLoading()
      this.appendMessage("assistant", data.content, true)
    }
  }

  finalizeResponse() {
    if (this.smdParser) {
      this.smdParser.end()
    }
    const html = this.responseTarget.innerHTML
    this.responseTarget.innerHTML = ""
    this.hideResponseWrapper()
    this.appendRenderedMessage("assistant", html)
    this.highlightCodeBlocks()
    this.isStreaming = false
    this.smdParser = null
    this.smdRenderer = null
  }

  // --- Sending ---

  send() {
    const message = this.inputTarget.value.trim()
    if (!message || this.isStreaming) return

    this.appendMessage("user", message)
    this.inputTarget.value = ""
    this.inputTarget.style.height = "auto"
    this.showLoading()
    this.autoScroll()

    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
      },
      body: JSON.stringify({ message })
    }).catch(() => {
      this.hideLoading()
      this.appendMessage("assistant", "Failed to send message. Please try again.", true)
    })
  }

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.send()
    }
  }

  // --- History ---

  async loadHistory() {
    try {
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("conversable_type", this.conversableTypeValue)
      url.searchParams.set("conversable_id", this.conversableIdValue)

      const response = await fetch(url, {
        headers: { "Accept": "application/json" }
      })
      if (!response.ok) return

      const data = await response.json()
      data.messages.forEach(msg => {
        this.appendMessage(msg.role, msg.content)
      })
      this.scrollToBottom()
    } catch (e) {
      // Silently fail - history is not critical
    }
  }

  // --- DOM Helpers ---

  appendMessage(role, content, isError = false) {
    const wrapper = document.createElement("div")
    wrapper.className = `flex ${role === "user" ? "justify-end" : "justify-start"} mb-3`

    const bubble = document.createElement("div")
    bubble.className = role === "user"
      ? "max-w-[85%] px-4 py-3 rounded-2xl rounded-br-sm bg-indigo-600 text-white text-sm"
      : `max-w-[85%] px-4 py-3 rounded-2xl rounded-bl-sm text-sm ${isError ? "bg-red-50 text-red-700 border border-red-200" : "bg-white border border-gray-200 text-gray-800"}`

    if (role === "assistant" && !isError) {
      bubble.innerHTML = this.renderMarkdown(content)
    } else {
      bubble.textContent = content
    }

    // Copy button for assistant messages
    if (role === "assistant" && !isError) {
      const copyBtn = document.createElement("button")
      copyBtn.className = "mt-2 text-xs text-gray-400 hover:text-gray-600 flex items-center gap-1"
      copyBtn.innerHTML = '<svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"></path></svg> Copy'
      copyBtn.onclick = () => {
        navigator.clipboard.writeText(content)
        copyBtn.innerHTML = '<svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg> Copied!'
        setTimeout(() => {
          copyBtn.innerHTML = '<svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"></path></svg> Copy'
        }, 2000)
      }
      bubble.appendChild(copyBtn)
    }

    wrapper.appendChild(bubble)
    this.messagesTarget.appendChild(wrapper)
  }

  appendRenderedMessage(role, html) {
    const wrapper = document.createElement("div")
    wrapper.className = "flex justify-start mb-3"

    const bubble = document.createElement("div")
    bubble.className = "max-w-[85%] px-4 py-3 rounded-2xl rounded-bl-sm bg-white border border-gray-200 text-gray-800 text-sm prose prose-sm max-w-none"
    bubble.innerHTML = html

    // Copy button
    const copyBtn = document.createElement("button")
    copyBtn.className = "mt-2 text-xs text-gray-400 hover:text-gray-600 flex items-center gap-1"
    copyBtn.innerHTML = '<svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"></path></svg> Copy'
    copyBtn.onclick = () => {
      navigator.clipboard.writeText(bubble.innerText)
      copyBtn.innerHTML = '<svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg> Copied!'
      setTimeout(() => {
        copyBtn.innerHTML = '<svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"></path></svg> Copy'
      }, 2000)
    }
    bubble.appendChild(copyBtn)

    wrapper.appendChild(bubble)
    this.messagesTarget.appendChild(wrapper)
  }

  renderMarkdown(text) {
    // Basic markdown to HTML for history messages (not streamed)
    // streaming-markdown handles streamed content; this is for pre-loaded history
    return text
      .replace(/```(\w*)\n([\s\S]*?)```/g, '<pre><code class="language-$1">$2</code></pre>')
      .replace(/`([^`]+)`/g, '<code>$1</code>')
      .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
      .replace(/\*([^*]+)\*/g, '<em>$1</em>')
      .replace(/\n/g, '<br>')
  }

  highlightCodeBlocks() {
    this.messagesTarget.querySelectorAll("pre code").forEach((block) => {
      hljs.highlightElement(block)
    })
  }

  // --- Loading ---

  showLoading() {
    if (this.hasLoadingTarget) this.loadingTarget.classList.remove("hidden")
  }

  hideLoading() {
    if (this.hasLoadingTarget) this.loadingTarget.classList.add("hidden")
  }

  showResponseWrapper() {
    if (this.hasResponseWrapperTarget) this.responseWrapperTarget.classList.remove("hidden")
  }

  hideResponseWrapper() {
    if (this.hasResponseWrapperTarget) this.responseWrapperTarget.classList.add("hidden")
  }

  // --- Scroll ---

  setupScrollDetection() {
    this.messagesTarget.addEventListener("scroll", () => {
      const el = this.messagesTarget
      this.userScrolledUp = (el.scrollHeight - el.scrollTop - el.clientHeight) > 50
    })
  }

  autoScroll() {
    if (!this.userScrolledUp) {
      this.scrollToBottom()
    }
  }

  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  // --- Resize ---

  setupResize() {
    if (!this.hasResizerTarget) return

    this.resizerTarget.addEventListener("mousedown", (e) => {
      e.preventDefault()
      const sidebar = this.hasSidebarTarget ? this.sidebarTarget : this.element
      const startX = e.clientX
      const startWidth = sidebar.offsetWidth

      const onMouseMove = (e) => {
        const newWidth = Math.max(320, Math.min(800, startWidth + (startX - e.clientX)))
        sidebar.style.width = `${newWidth}px`
      }

      const onMouseUp = () => {
        document.removeEventListener("mousemove", onMouseMove)
        document.removeEventListener("mouseup", onMouseUp)
      }

      document.addEventListener("mousemove", onMouseMove)
      document.addEventListener("mouseup", onMouseUp)
    })
  }

  // --- Cleanup ---

  disconnect() {
    this.subscription?.unsubscribe()
    this.consumer?.disconnect()
  }
}
