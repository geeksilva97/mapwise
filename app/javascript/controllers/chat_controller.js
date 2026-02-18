import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"
import { request } from "utils/http"

export default class extends Controller {
  static values = { mapId: Number }
  static targets = ["messages", "input", "submitButton"]

  connect() {
    this.#subscribe()
    this.#scrollToBottom()
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }
  }

  async submit(event) {
    event.preventDefault()
    const content = this.inputTarget.value.trim()
    if (!content) return

    this.inputTarget.value = ""
    this.#setInputEnabled(false)

    // Remove empty state if present
    const emptyState = document.getElementById("chat_empty_state")
    if (emptyState) emptyState.remove()

    // Optimistically append user message bubble
    this.messagesTarget.insertAdjacentHTML("beforeend", this.#userBubbleHTML(content))
    this.#scrollToBottom()

    // Show thinking indicator
    this.messagesTarget.insertAdjacentHTML("beforeend", this.#thinkingHTML())
    this.#scrollToBottom()

    // POST to create chat message
    try {
      await request(`/maps/${this.mapIdValue}/chat_messages`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "text/html" },
        body: JSON.stringify({ chat_message: { content } })
      })
    } catch {
      this.#removeThinking()
      this.messagesTarget.insertAdjacentHTML("beforeend",
        this.#assistantBubbleHTML("Sorry, something went wrong. Please try again."))
      this.#setInputEnabled(true)
      this.#scrollToBottom()
    }
    // On success, the response comes via Action Cable — input re-enabled in #handleMessage
  }

  #subscribe() {
    this.subscription = consumer.subscriptions.create(
      { channel: "AiChatChannel", map_id: this.mapIdValue },
      {
        received: (data) => this.#handleMessage(data)
      }
    )
  }

  #handleMessage(data) {
    if (data.type === "tool_update") {
      this.#syncMapState(data)
      return
    }

    if (data.type !== "assistant_message") return

    this.#syncMapState(data)

    // Remove thinking indicator
    this.#removeThinking()

    // Append assistant message
    this.messagesTarget.insertAdjacentHTML("beforeend", data.html)

    this.#setInputEnabled(true)
    this.inputTarget.focus()
    this.#scrollToBottom()
  }

  #syncMapState(data) {
    // Update markers and groups on the map controller
    const mapCanvas = document.getElementById("map-canvas")
    if (mapCanvas) {
      const mapController = this.application.getControllerForElementAndIdentifier(mapCanvas, "map")
      if (mapController) {
        if (data.markers_json) {
          mapController.markersValue = JSON.parse(data.markers_json)
        }
        if (data.groups_json) {
          mapController.groupsValue = JSON.parse(data.groups_json)
        }
        if (data.style_json) {
          mapController.applyStyle(data.style_json)
        }
        if (data.center_lat && data.center_lng) {
          mapController.panTo(data.center_lat, data.center_lng, data.zoom)
        }
      }
    }

    // Update sidebar markers list
    const markersList = document.getElementById("markers_list")
    if (markersList && data.markers_html !== undefined) {
      markersList.innerHTML = data.markers_html
    }

    // Update marker count
    const countEl = document.querySelector("[data-marker-editor-target='count']")
    if (countEl && data.marker_count !== undefined) {
      countEl.textContent = data.marker_count
    }

    // Remove empty state message if markers exist
    const emptyMsg = document.getElementById("markers_empty")
    if (emptyMsg && data.marker_count > 0) {
      emptyMsg.remove()
    }
  }

  #setInputEnabled(enabled) {
    this.inputTarget.disabled = !enabled
    this.submitButtonTarget.disabled = !enabled
  }

  #removeThinking() {
    const thinking = document.getElementById("thinking_indicator")
    if (thinking) thinking.remove()
  }

  #scrollToBottom() {
    requestAnimationFrame(() => {
      if (this.hasMessagesTarget) {
        this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
      }
    })
  }

  #userBubbleHTML(content) {
    const escaped = this.#escapeHTML(content)
    return `<div class="flex mb-3 justify-end">
      <div class="max-w-[85%] rounded-2xl px-4 py-2.5 text-sm leading-relaxed rounded-br-sm bg-blue-600 text-white">
        <span>${escaped}</span>
      </div>
    </div>`
  }

  #assistantBubbleHTML(content) {
    const escaped = this.#escapeHTML(content)
    return `<div class="flex mb-3 justify-start">
      <div class="max-w-[85%] rounded-2xl px-4 py-2.5 text-sm leading-relaxed rounded-bl-sm bg-gray-100 text-gray-800">
        <span>${escaped}</span>
      </div>
    </div>`
  }

  #thinkingHTML() {
    return `<div id="thinking_indicator" class="flex mb-3 justify-start">
      <div class="max-w-[85%] rounded-2xl rounded-bl-sm px-4 py-2.5 bg-gray-100 text-gray-800">
        <div class="flex items-center gap-1.5">
          <span class="w-1.5 h-1.5 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0ms"></span>
          <span class="w-1.5 h-1.5 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 150ms"></span>
          <span class="w-1.5 h-1.5 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 300ms"></span>
        </div>
      </div>
    </div>`
  }

  #escapeHTML(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
