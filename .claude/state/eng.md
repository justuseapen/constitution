# Engineering State - Constitution

## Last Updated
2026-02-26T23:45:00Z

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
| ServiceSystem & SystemDependency Models | Complete | master | System Registry data layer with microservice architecture mapping |

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
Task 16 complete: ServiceSystem & SystemDependency Models implemented.

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

Key files created/modified:
- **Migrations:**
  - `db/migrate/20260226180000_create_service_systems.rb` - Team-scoped systems table with system_type enum
  - `db/migrate/20260226180001_create_system_dependencies.rb` - Source/target dependencies with unique constraint

- **Models:**
  - `app/models/service_system.rb` - GraphSync integration, custom graph_label "System"
  - `app/models/system_dependency.rb` - Custom graph sync with typed edges based on dependency_type
  - `app/models/team.rb` - Added has_many :service_systems association

- **Specs:**
  - `spec/models/service_system_spec.rb` - Validations, associations, enum, GraphSync behavior
  - `spec/models/system_dependency_spec.rb` - Associations, enum, graph edge creation

- **Factories:**
  - `spec/factories/service_systems.rb` - Uses Faker::App.name
  - `spec/factories/system_dependencies.rb` - Source/target associations with metadata

Commit: 41d49c2 "feat: add ServiceSystem and SystemDependency models with graph sync"

Features implemented:
- **ServiceSystem Model:**
  - Includes GraphSync concern for automatic Neo4j node sync
  - Belongs to team, has_many repositories
  - Has_many outgoing_dependencies and incoming_dependencies (self-referential through SystemDependency)
  - Enum system_type: service, library, database, queue, external_api
  - Custom graph_label returns "System" for Neo4j node labeling
  - Custom graph_properties includes postgres_id, title (name), and system_type

- **SystemDependency Model:**
  - Belongs to source_system and target_system (both ServiceSystem)
  - Enum dependency_type: http_api, rabbitmq, grpc, database_shared, event_bus, sdk
  - Uniqueness validation on source_system_id scoped to target_system_id and dependency_type
  - Custom graph sync callbacks (not using GraphSync concern):
    - sync_edge_to_graph: creates typed Neo4j edges based on dependency_type
      - http_api → CALLS_API
      - rabbitmq → PUBLISHES_TO
      - grpc → CALLS_GRPC
      - database_shared → READS_FROM
      - event_bus → PUBLISHES_TO
      - sdk → USES_SDK
      - default → DEPENDS_ON
    - remove_edge_from_graph: deletes Neo4j edge on destroy
  - Edge properties include dependency_type and metadata JSON

- **Database Schema:**
  - service_systems table: team_id (FK), name (required), description, repo_url, system_type (integer enum, default 0)
  - system_dependencies table: source_system_id (FK), target_system_id (FK), dependency_type (integer enum, default 0), description, metadata (jsonb, default {})
  - Unique constraint: idx_sys_deps_unique on (source_system_id, target_system_id, dependency_type)

- **Team Association:**
  - Added has_many :service_systems to Team model for team-scoped system ownership

Implementation notes:
- ServiceSystem uses GraphSync concern like other models (Document, Blueprint, etc)
- SystemDependency has custom graph sync logic to create TYPED edges (not just generic relationships)
- Edge type mapping allows for rich graph queries (e.g., "show all HTTP API calls")
- Metadata jsonb field allows storing connection-specific details (endpoints, topics, etc)
- Repository association prepared for future task (repository model not yet created)
- All syntax validated with ruby -c, no database required for creation

Technical decisions:
- SystemDependency does NOT include GraphSync because it represents an EDGE, not a NODE
- Custom callbacks on SystemDependency control edge creation/deletion lifecycle
- Edge properties stored as JSON to handle metadata and dependency_type serialization
- Unique constraint prevents duplicate dependencies of same type between same systems
- Source/target naming convention clarifies directionality of dependencies

Ready for next task: System Registry data layer complete. Can now build Repository model, or add CRUD controllers/views for managing service systems and their dependencies.
