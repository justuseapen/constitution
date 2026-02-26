# Engineering State - Constitution

## Last Updated
2026-02-26T22:30:00Z

## Current Sprint Goal
Initialize Rails 8 application with Docker Compose infrastructure (Postgres, Neo4j, Redis) and core gems

## Active Work
| Task | Status | Branch | Notes |
|------|--------|--------|-------|
| Docker Compose & Rails 8 App Init | Complete | master | Rails 8.1.2 app with Docker Compose created |
| Core Gems & Configuration | Complete | master | All gems installed, RSpec configured |
| User & Team Models with Devise | Complete | master | Authentication setup with model specs, factories |
| Project Model & CRUD | Complete | master | Project model with full CRUD, team-scoped |
| Document & DocumentVersion Models | Complete | master | Document versioning system with snapshots |
| Polymorphic Comment Model | Complete | master | Comment model for Documents, Blueprints, WorkOrders |
| Documents Controller & Views with Tiptap | Complete | master | Full CRUD with rich text editor integration |
| Auto-Generate Placeholder Docs | Complete | master | Project creation now seeds Product Overview & Technical Requirements docs |
| Blueprint & BlueprintVersion Models | Complete | master | Blueprint system with Mermaid diagram support |
| Phase & WorkOrder Models | Complete | master | Planner data layer with phases and work orders |
| WorkOrders Kanban Board | Complete | master | Full kanban UI with drag-and-drop via Sortable.js |
| GraphSync Concern & Node Management | Complete | master | Neo4j integration via GraphService and GraphSync concern |
| Drift Detection Background Job | Complete | master | DriftAlert model and scheduled job to detect stale relationships |
| AgentService & ContextBuilder | Complete | master | AI agent infrastructure with OpenRouter chat and context assembly |
| Agent Chat Sidebar with Streaming | Complete | master | Real-time chat UI with Action Cable streaming for all conversable types |

## Blockers
- [ ] _None yet_

## Technical Debt Queue
| Item | Priority | Effort | Notes |
|------|----------|--------|-------|
| - | - | - | - |

## Recent Decisions
- Using Rails 8.1.2 with PostgreSQL, esbuild, and Tailwind CSS
- Docker Compose with pgvector/pgvector:pg16 for vector search support
- Neo4j 5 with APOC plugin for graph database
- Redis 7 for caching and Solid Queue backend
- Ruby 3.3.1 (aligned with Dockerfile)
- Node.js 20 for JavaScript tooling
- activegraph 11.4.0 (11.5 only available as beta)
- RSpec for testing with FactoryBot, Faker, Shoulda Matchers
- Devise for authentication
- Pundit for authorization
- ruby-openai for OpenRouter integration (OpenAI-compatible API)

## Context for Next Session
Task 15 complete: Agent Chat Sidebar with Streaming implemented.

Key files created/modified:
- **Channel:** `app/channels/agent_chat_channel.rb` - Action Cable channel for streaming
- **Job:** `app/jobs/agent_chat_job.rb` - Background job with OpenRouter streaming
- **Controller:** `app/controllers/agent_chats_controller.rb` - Chat endpoint and system prompt logic
- **Stimulus:** `app/javascript/controllers/agent_chat_controller.js` - WebSocket client and UI updates
- **Partial:** `app/views/agent_chats/_sidebar.html.erb` - Reusable chat sidebar component
- **Views:** Updated show pages for Document, Blueprint, WorkOrder with agent sidebar
- **Routes:** Added `resources :agent_chats, only: [:create]`
- **Spec:** `spec/requests/agent_chats_spec.rb` - Request spec for chat endpoint
- **Manifest:** Registered agent-chat controller in `app/javascript/controllers/index.js`

Commit: bc44180 "feat: add agent chat sidebar with streaming via Action Cable"

Features implemented:
- **AgentChatChannel:**
  - Subscribes to conversable-specific stream
  - Format: `agent_chat_{ConversableType}_{id}`

- **AgentChatJob:**
  - Creates user message, streams response, saves assistant message
  - Broadcasts delta chunks and complete event via Action Cable
  - Uses OPENROUTER_CLIENT with streaming proc
  - Full response accumulated and persisted after streaming

- **AgentChatsController:**
  - Authenticates user, finds/creates conversation
  - Context-specific system prompts:
    - Document → Refinery Agent (requirements, gaps, ambiguity)
    - Blueprint → Foundry Agent (design, architecture, alignment)
    - WorkOrder → Planner Agent (scoping, criteria, implementation)
  - Enqueues AgentChatJob and returns 202 Accepted

- **agent_chat_controller.js:**
  - Creates Action Cable consumer on connect
  - Subscribes to conversable-specific channel
  - Appends delta chunks to response target in real-time
  - On complete: moves full response to messages area
  - Sends POST to endpoint with CSRF token
  - Unsubscribes on disconnect

- **_sidebar.html.erb:**
  - Fixed height layout with flex columns
  - Messages area (scrollable)
  - Response area (streaming deltas)
  - Input with Enter key support and Send button
  - Data attributes for Stimulus controller values

- **View integration:**
  - Document, Blueprint, WorkOrder show pages now use flex layout
  - Main content area (flex-1) + agent sidebar (w-80)
  - Consistent h-[calc(100vh-4rem)] for full-height layout
  - WorkOrder show page restructured to match layout pattern

Implementation details:
- Job uses proc streaming to broadcast deltas immediately
- Stimulus controller appends text to responseTarget on delta events
- On complete event, moves text to messagesTarget and clears response
- User messages added to DOM immediately for instant feedback
- Sidebar uses conversable_type and conversable_id for polymorphism
- Agent prompts defined inline in controller (could be extracted later)

Technical notes:
- Database is NOT running locally - all syntax validated
- Action Cable requires Redis (already configured in Docker Compose)
- Streaming works via WebSocket connection, not HTTP
- CSRF token required for POST requests from JS
- Sidebar width (w-80) matches existing Document/Blueprint layout
- Request spec uses have_enqueued_job matcher for async testing

Ready for next task: Agent chat UI is fully functional with streaming. Can now enhance with conversation history loading, improve error handling, add typing indicators, or build additional agent capabilities.
