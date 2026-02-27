# Document Auto-Population & Chat UI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** When a repo is connected to a project, auto-populate the existing seed documents with AI-generated content from the indexed codebase. Fix the broken agent chat and upgrade it to a ChatGPT-style experience with streaming markdown.

**Architecture:** Modify `GenerateRequirementsJob` to update existing seed docs in-place (finding by `document_type`). Fix `AgentChatJob` to include system prompt in messages. Replace the chat UI Stimulus controller and sidebar partial with a full-featured chat using `streaming-markdown` for incremental rendering.

**Tech Stack:** Rails 8, Stimulus.js, ActionCable, streaming-markdown (npm), highlight.js (npm), OpenRouter API

---

### Task 1: Fix GenerateRequirementsJob to Update Seed Documents In-Place

**Files:**
- Modify: `app/jobs/generate_requirements_job.rb`
- Test: `spec/jobs/generate_requirements_job_spec.rb` (create)

**Step 1: Write the failing test**

Create `spec/jobs/generate_requirements_job_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe GenerateRequirementsJob, type: :job do
  let(:team) { create(:team) }
  let(:user) { create(:user, team: team) }
  let(:project) { create(:project, team: team) }
  let(:service_system) { create(:service_system, team: team) }
  let(:repository) { create(:repository, service_system: service_system, indexing_status: :indexed) }

  before do
    Project.seed_documents(project, user)

    file = create(:codebase_file, repository: repository, path: "app/models/user.rb", language: "ruby")
    create(:extracted_artifact, codebase_file: file, artifact_type: :data_model, name: "User")
    create(:extracted_artifact, codebase_file: file, artifact_type: :route, name: "GET /users")

    stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
      .to_return(status: 200, body: {
        choices: [{ message: { content: "<h2>Overview</h2><p>AI-generated content</p>" } }]
      }.to_json, headers: { "Content-Type" => "application/json" })
  end

  it "updates the existing product_overview document in-place" do
    expect(project.documents.product_overview.count).to eq(1)
    original_doc = project.documents.find_by(document_type: :product_overview)
    original_id = original_doc.id

    GenerateRequirementsJob.perform_now(project_id: project.id, user_id: user.id, repository_id: repository.id)

    expect(project.documents.product_overview.count).to eq(1)
    updated_doc = project.documents.find_by(document_type: :product_overview)
    expect(updated_doc.id).to eq(original_id)
    expect(updated_doc.body).to include("AI-generated content")
    expect(updated_doc.status).to eq("ai_generated")
  end

  it "updates the existing technical_requirement document in-place" do
    expect(project.documents.technical_requirement.count).to eq(1)

    GenerateRequirementsJob.perform_now(project_id: project.id, user_id: user.id, repository_id: repository.id)

    expect(project.documents.technical_requirement.count).to eq(1)
    doc = project.documents.find_by(document_type: :technical_requirement)
    expect(doc.body).to include("AI-generated content")
  end

  it "creates a version snapshot before updating" do
    GenerateRequirementsJob.perform_now(project_id: project.id, user_id: user.id, repository_id: repository.id)

    doc = project.documents.find_by(document_type: :product_overview)
    expect(doc.versions.count).to eq(1)
    expect(doc.versions.first.body_snapshot).to include("Business Problem")
  end

  it "creates documents if none exist for that type" do
    project.documents.destroy_all

    GenerateRequirementsJob.perform_now(project_id: project.id, user_id: user.id, repository_id: repository.id)

    expect(project.documents.product_overview.count).to eq(1)
    expect(project.documents.technical_requirement.count).to eq(1)
  end

  it "requeues if repository is still indexing" do
    repository.update!(indexing_status: :indexing)

    expect {
      GenerateRequirementsJob.perform_now(project_id: project.id, user_id: user.id, repository_id: repository.id)
    }.to have_enqueued_job(GenerateRequirementsJob)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/justuseapen/Dropbox/code/constitution && bundle exec rspec spec/jobs/generate_requirements_job_spec.rb -v`
Expected: FAIL (tests reference new behavior not yet implemented)

**Step 3: Write the implementation**

Replace `app/jobs/generate_requirements_job.rb`:

```ruby
class GenerateRequirementsJob < ApplicationJob
  queue_as :default

  def perform(project_id:, user_id:, repository_id:)
    project = Project.find(project_id)
    user = User.find(user_id)
    repository = Repository.find(repository_id)

    return requeue(project_id, user_id, repository_id) if repository.indexing?

    artifacts = repository.codebase_files
      .joins(:extracted_artifacts)
      .includes(:extracted_artifacts)
      .limit(100)

    return if artifacts.empty?

    context = build_artifact_summary(artifacts)
    update_or_create_document(project, user, context, :product_overview, "Product Overview")
    update_or_create_document(project, user, context, :technical_requirement, "Technical Requirements")
  end

  private

  def requeue(project_id, user_id, repository_id)
    self.class.set(wait: 30.seconds).perform_later(
      project_id: project_id,
      user_id: user_id,
      repository_id: repository_id
    )
  end

  def build_artifact_summary(artifacts)
    summary = []
    artifacts.flat_map(&:extracted_artifacts).group_by(&:artifact_type).each do |type, items|
      summary << "## #{type.humanize.pluralize}"
      items.first(20).each { |a| summary << "- #{a.name}" }
    end
    summary.join("\n")
  end

  def update_or_create_document(project, user, context, doc_type, title)
    return unless defined?(OPENROUTER_CLIENT) && OPENROUTER_CLIENT.present?

    prompt = build_prompt(doc_type, context)

    response = OPENROUTER_CLIENT.chat(
      parameters: {
        model: "anthropic/claude-sonnet-4-5-20250929",
        messages: [{ role: "user", content: prompt }]
      }
    )

    body = response.dig("choices", 0, "message", "content")
    return unless body

    existing = project.documents.find_by(document_type: doc_type)
    if existing
      existing.create_version!(user)
      existing.update!(body: body, updated_by: user, status: "ai_generated")
    else
      project.documents.create!(
        title: title,
        body: body,
        document_type: doc_type,
        created_by: user,
        status: "ai_generated"
      )
    end
  end

  def build_prompt(doc_type, context)
    case doc_type
    when :product_overview
      <<~PROMPT
        Based on the following extracted code artifacts from a repository, generate a Product Overview document.
        Include these sections as HTML headings (<h2>) with substantive content:
        - What the application does (inferred from models, routes, and services)
        - Key technologies and frameworks used
        - Target users (inferred from the domain and features)
        - Core features and capabilities

        Format the output as clean HTML suitable for a rich text editor. Use <h2> for headings and <p> for paragraphs.
        Do NOT wrap in markdown code fences. Output raw HTML only.

        Artifacts:
        #{context}
      PROMPT
    when :technical_requirement
      <<~PROMPT
        Based on the following extracted code artifacts from a repository, generate a Technical Requirements document.
        Include these sections as HTML headings (<h2>) with substantive content:
        - Data Models (list the key models and their relationships)
        - API Routes and Endpoints
        - Services and Business Logic
        - Infrastructure and Dependencies
        - Authentication and Authorization (if present)
        - Performance Considerations

        Format the output as clean HTML suitable for a rich text editor. Use <h2> for headings and <p> for paragraphs.
        Do NOT wrap in markdown code fences. Output raw HTML only.

        Artifacts:
        #{context}
      PROMPT
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/justuseapen/Dropbox/code/constitution && bundle exec rspec spec/jobs/generate_requirements_job_spec.rb -v`
Expected: All 5 tests PASS

**Step 5: Commit**

```bash
git add spec/jobs/generate_requirements_job_spec.rb app/jobs/generate_requirements_job.rb
git commit -m "feat: update seed documents in-place when repo is indexed"
```

---

### Task 2: Fix AgentChatJob System Prompt Bug

**Files:**
- Modify: `app/jobs/agent_chat_job.rb:4-33`
- Test: `spec/jobs/agent_chat_job_spec.rb` (create)

**Step 1: Write the failing test**

Create `spec/jobs/agent_chat_job_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe AgentChatJob, type: :job do
  let(:team) { create(:team) }
  let(:user) { create(:user, team: team) }
  let(:project) { create(:project, team: team) }
  let(:document) { create(:document, project: project, created_by: user) }
  let(:conversation) do
    AgentConversation.create!(
      conversable: document,
      user: user,
      model_provider: "openrouter",
      model_name: "anthropic/claude-sonnet-4-5-20250929"
    )
  end
  let(:system_prompt) { "You are the Refinery Agent." }

  before do
    stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
      .to_return(status: 200, body: {
        choices: [{ message: { content: "Here is my response." } }]
      }.to_json, headers: { "Content-Type" => "application/json" })
  end

  it "includes the system prompt as the first message" do
    messages_sent = nil
    allow(OPENROUTER_CLIENT).to receive(:chat) do |params|
      messages_sent = params[:parameters][:messages]
      { "choices" => [{ "message" => { "content" => "Response" } }] }
    end

    AgentChatJob.perform_now(
      conversation_id: conversation.id,
      message: "Hello",
      system_prompt: system_prompt
    )

    expect(messages_sent.first[:role]).to eq("system")
    expect(messages_sent.first[:content]).to eq(system_prompt)
  end

  it "saves the user message and assistant response" do
    allow(OPENROUTER_CLIENT).to receive(:chat).and_return(
      { "choices" => [{ "message" => { "content" => "Response" } }] }
    )

    AgentChatJob.perform_now(
      conversation_id: conversation.id,
      message: "Hello",
      system_prompt: system_prompt
    )

    expect(conversation.messages.where(role: "user").count).to eq(1)
    expect(conversation.messages.where(role: "assistant").count).to eq(1)
    expect(conversation.messages.where(role: "assistant").last.content).to eq("Response")
  end

  it "broadcasts an error on failure" do
    allow(OPENROUTER_CLIENT).to receive(:chat).and_raise(StandardError, "API error")

    expect(ActionCable.server).to receive(:broadcast).with(
      "agent_chat_Document_#{document.id}",
      hash_including(type: "error")
    )

    AgentChatJob.perform_now(
      conversation_id: conversation.id,
      message: "Hello",
      system_prompt: system_prompt
    )
  end
end
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/justuseapen/Dropbox/code/constitution && bundle exec rspec spec/jobs/agent_chat_job_spec.rb -v`
Expected: FAIL (system prompt not included, no error handling)

**Step 3: Write the implementation**

Replace `app/jobs/agent_chat_job.rb`:

```ruby
class AgentChatJob < ApplicationJob
  queue_as :default

  def perform(conversation_id:, message:, system_prompt:)
    conversation = AgentConversation.find(conversation_id)
    conversation.messages.create!(role: "user", content: message)

    channel = "agent_chat_#{conversation.conversable_type}_#{conversation.conversable_id}"

    messages = [{ role: "system", content: system_prompt }]
    messages += conversation.messages.order(:created_at).map { |m| { role: m.role, content: m.content } }

    full_response = ""
    OPENROUTER_CLIENT.chat(
      parameters: {
        model: conversation.model_name,
        messages: messages,
        stream: proc { |chunk|
          delta = chunk.dig("choices", 0, "delta", "content")
          if delta
            full_response += delta
            ActionCable.server.broadcast(channel, { type: "delta", content: delta })
          end
        }
      }
    )

    conversation.messages.create!(role: "assistant", content: full_response)
    ActionCable.server.broadcast(channel, { type: "complete" })
  rescue StandardError => e
    Rails.logger.error("AgentChatJob failed: #{e.message}")
    channel = "agent_chat_#{AgentConversation.find(conversation_id).then { |c| "#{c.conversable_type}_#{c.conversable_id}" }}" rescue nil
    if channel
      ActionCable.server.broadcast(channel, { type: "error", content: "Sorry, something went wrong. Please try again." })
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/justuseapen/Dropbox/code/constitution && bundle exec rspec spec/jobs/agent_chat_job_spec.rb -v`
Expected: All 3 tests PASS

**Step 5: Commit**

```bash
git add app/jobs/agent_chat_job.rb spec/jobs/agent_chat_job_spec.rb
git commit -m "fix: include system prompt in agent chat and add error handling"
```

---

### Task 3: Add Conversation History Endpoint

**Files:**
- Modify: `app/controllers/agent_chats_controller.rb`
- Modify: `config/routes.rb:20`
- Test: `spec/requests/agent_chats_spec.rb` (modify)

**Step 1: Write the failing test**

Add to `spec/requests/agent_chats_spec.rb`:

```ruby
  describe "GET /agent_chats" do
    it "returns conversation messages for a conversable" do
      conversation = AgentConversation.create!(
        conversable: document, user: user,
        model_provider: "openrouter", model_name: "test"
      )
      conversation.messages.create!(role: "user", content: "Hello")
      conversation.messages.create!(role: "assistant", content: "Hi there")

      get agent_chats_path, params: {
        conversable_type: "Document",
        conversable_id: document.id
      }, as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["messages"].length).to eq(2)
      expect(json["messages"][0]["role"]).to eq("user")
      expect(json["messages"][0]["content"]).to eq("Hello")
      expect(json["messages"][1]["role"]).to eq("assistant")
      expect(json["messages"][1]["content"]).to eq("Hi there")
    end

    it "returns empty messages when no conversation exists" do
      get agent_chats_path, params: {
        conversable_type: "Document",
        conversable_id: document.id
      }, as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["messages"]).to eq([])
    end
  end
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/justuseapen/Dropbox/code/constitution && bundle exec rspec spec/requests/agent_chats_spec.rb -v`
Expected: FAIL (no route matches GET /agent_chats)

**Step 3: Write the implementation**

Modify `config/routes.rb` line 20 from:
```ruby
  resources :agent_chats, only: [:create]
```
to:
```ruby
  resources :agent_chats, only: [:index, :create]
```

Add `index` action to `app/controllers/agent_chats_controller.rb`:

```ruby
class AgentChatsController < ApplicationController
  before_action :authenticate_user!

  def index
    conversation = AgentConversation.find_by(
      conversable_type: params[:conversable_type],
      conversable_id: params[:conversable_id],
      user: current_user
    )

    messages = if conversation
      conversation.messages.where.not(role: "system").order(:created_at).map do |m|
        { role: m.role, content: m.content, created_at: m.created_at }
      end
    else
      []
    end

    render json: { messages: messages }
  end

  def create
    conversable = params[:conversable_type].constantize.find(params[:conversable_id])
    conversation = AgentConversation.find_or_create_by!(
      conversable: conversable, user: current_user
    ) do |c|
      c.model_provider = "openrouter"
      c.model_name = "anthropic/claude-sonnet-4-5-20250929"
    end

    system_prompt = agent_system_prompt(conversable)
    AgentChatJob.perform_later(
      conversation_id: conversation.id,
      message: params[:message],
      system_prompt: system_prompt
    )

    head :accepted
  end

  private

  def agent_system_prompt(conversable)
    case conversable
    when Document
      "You are the Refinery Agent. Help the user refine requirements, identify gaps, resolve ambiguity, and improve document quality. Focus on making requirements clear, testable, and complete."
    when Blueprint
      "You are the Foundry Agent. Help the user design and refine technical blueprints. Suggest architectural improvements, identify missing components, and ensure alignment with requirements."
    when WorkOrder
      "You are the Planner Agent. Help the user refine work orders, improve acceptance criteria, suggest implementation approaches, and ensure work orders are well-scoped and actionable."
    else
      "You are a helpful assistant for the Constitution SDLC platform."
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/justuseapen/Dropbox/code/constitution && bundle exec rspec spec/requests/agent_chats_spec.rb -v`
Expected: All 3 tests PASS (1 existing + 2 new)

**Step 5: Commit**

```bash
git add config/routes.rb app/controllers/agent_chats_controller.rb spec/requests/agent_chats_spec.rb
git commit -m "feat: add conversation history endpoint for agent chat"
```

---

### Task 4: Install streaming-markdown and highlight.js

**Files:**
- Modify: `package.json`

**Step 1: Install packages**

Run: `cd /Users/justuseapen/Dropbox/code/constitution && npm install streaming-markdown highlight.js`

**Step 2: Verify installation**

Run: `cd /Users/justuseapen/Dropbox/code/constitution && node -e "require('streaming-markdown'); console.log('smd OK')" && node -e "require('highlight.js'); console.log('hljs OK')"`
Expected: Both print "OK"

**Step 3: Build to verify no errors**

Run: `cd /Users/justuseapen/Dropbox/code/constitution && npm run build`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add package.json package-lock.json
git commit -m "chore: add streaming-markdown and highlight.js dependencies"
```

---

### Task 5: Rewrite Agent Chat Stimulus Controller

**Files:**
- Modify: `app/javascript/controllers/agent_chat_controller.js`

**Step 1: Write the new controller**

Replace `app/javascript/controllers/agent_chat_controller.js`:

```javascript
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
```

**Step 2: Build to verify no JS errors**

Run: `cd /Users/justuseapen/Dropbox/code/constitution && npm run build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add app/javascript/controllers/agent_chat_controller.js
git commit -m "feat: rewrite agent chat controller with streaming markdown and full UX"
```

---

### Task 6: Rewrite Chat Sidebar Partial

**Files:**
- Modify: `app/views/agent_chats/_sidebar.html.erb`

**Step 1: Write the new partial**

Replace `app/views/agent_chats/_sidebar.html.erb`:

```erb
<div class="w-[400px] border-l bg-gray-50 flex flex-col h-full relative"
     data-controller="agent-chat"
     data-agent-chat-target="sidebar"
     data-agent-chat-conversable-type-value="<%= conversable_type %>"
     data-agent-chat-conversable-id-value="<%= conversable_id %>"
     data-agent-chat-url-value="<%= agent_chats_path(conversable_type: conversable_type, conversable_id: conversable_id) %>">

  <%# Resize handle %>
  <div data-agent-chat-target="resizer"
       class="absolute left-0 top-0 bottom-0 w-1 cursor-col-resize hover:bg-indigo-400 active:bg-indigo-500 z-10"></div>

  <%# Header %>
  <div class="p-4 border-b bg-white flex items-center gap-2">
    <div class="w-7 h-7 rounded-full bg-indigo-600 flex items-center justify-center flex-shrink-0">
      <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z"></path>
      </svg>
    </div>
    <div>
      <h3 class="font-semibold text-sm text-gray-900">AI Agent</h3>
      <p class="text-xs text-gray-500">Ask questions about this artifact</p>
    </div>
  </div>

  <%# Messages area %>
  <div data-agent-chat-target="messages"
       class="flex-1 overflow-y-auto p-4 space-y-1"
       style="scroll-behavior: smooth;">
  </div>

  <%# Loading indicator %>
  <div data-agent-chat-target="loading" class="hidden px-4 pb-2">
    <div class="flex items-center gap-2 text-gray-400 text-sm">
      <div class="flex gap-1">
        <span class="w-1.5 h-1.5 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0ms"></span>
        <span class="w-1.5 h-1.5 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 150ms"></span>
        <span class="w-1.5 h-1.5 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 300ms"></span>
      </div>
      <span>Thinking...</span>
    </div>
  </div>

  <%# Streaming response area %>
  <div data-agent-chat-target="responseWrapper" class="hidden px-4 pb-2">
    <div class="flex justify-start mb-3">
      <div data-agent-chat-target="response"
           class="max-w-[85%] px-4 py-3 rounded-2xl rounded-bl-sm bg-white border border-gray-200 text-gray-800 text-sm prose prose-sm max-w-none">
      </div>
    </div>
  </div>

  <%# Input area %>
  <div class="p-3 border-t bg-white">
    <div class="flex gap-2 items-end">
      <textarea data-agent-chat-target="input"
                placeholder="Ask the agent..."
                rows="1"
                class="flex-1 border border-gray-300 rounded-xl px-4 py-2.5 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                data-action="keydown->agent-chat#handleKeydown"
                oninput="this.style.height='auto'; this.style.height=Math.min(this.scrollHeight, 120)+'px'"></textarea>
      <button data-action="click->agent-chat#send"
              class="px-4 py-2.5 bg-indigo-600 text-white rounded-xl text-sm font-medium hover:bg-indigo-700 transition-colors flex-shrink-0">
        Send
      </button>
    </div>
    <p class="text-xs text-gray-400 mt-1.5 text-center">Shift+Enter for new line</p>
  </div>
</div>
```

**Step 2: Add highlight.js CSS to application layout**

Check `app/views/layouts/application.html.erb` and add highlight.js theme CSS. Add this line in the `<head>`:

```erb
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css">
```

Alternatively, import it in the JS bundle. Either approach works.

**Step 3: Verify in browser**

Run: `cd /Users/justuseapen/Dropbox/code/constitution && bin/rails server`
Visit `http://localhost:3000`, navigate to a project document, and verify:
- Chat sidebar renders at ~400px width
- Resize handle works (drag left edge)
- Previous messages load (if any)
- Typing a message and pressing Enter sends it
- Loading dots appear
- Streaming response renders with markdown formatting
- Code blocks are syntax highlighted
- Copy button works
- Auto-scroll works during streaming

**Step 4: Commit**

```bash
git add app/views/agent_chats/_sidebar.html.erb app/views/layouts/application.html.erb
git commit -m "feat: upgrade chat sidebar with streaming markdown, resize, and full UX"
```

---

### Task 7: Run Full Test Suite

**Files:** None (verification only)

**Step 1: Run all specs**

Run: `cd /Users/justuseapen/Dropbox/code/constitution && bundle exec rspec`
Expected: All tests pass, including existing tests that weren't modified.

**Step 2: Build frontend**

Run: `cd /Users/justuseapen/Dropbox/code/constitution && npm run build && npm run build:css`
Expected: Both succeed

**Step 3: If any failures, fix them**

Fix any regressions introduced by the changes.

**Step 4: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix: address test regressions from chat and document changes"
```
