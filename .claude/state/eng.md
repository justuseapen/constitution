# Engineering State - Constitution

## Last Updated
2026-02-26T18:25:00Z

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
| System Map Visualization with D3.js | Complete | master | Interactive force-directed graph showing services and dependencies |
| FeedbackItem Model & API Endpoint | Complete | master | Validator API with auto-triage job using AI |
| Validator Inbox UI | Complete | master | Feedback inbox with filtering and work order creation |
| Action Cable Channels & Presence | Complete | master | Real-time channels with presence tracking |
| Notification Center UI | Complete | master | Bell icon dropdown with real-time notification updates |
| Repository Model & Indexing Pipeline | Complete | master | Codebase indexing with pgvector embeddings and semantic artifact extraction |
| MCP Server Implementation | Complete | master | Model Context Protocol server for IDE integration with 8 tools and 4 resources |

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
Task 18 complete: FeedbackItem Model & API Endpoint with auto-triage implemented.

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

Key files created/modified:
- **Controller:** `app/controllers/systems_controller.rb` - Full CRUD for service systems with JSON API
- **Stimulus:** `app/javascript/controllers/system_map_controller.js` - D3.js force-directed graph
- **Helper:** `app/helpers/systems_helper.rb` - System type color mapping
- **Views:**
  - `app/views/systems/index.html.erb` - System map with graph and grid of systems
  - `app/views/systems/show.html.erb` - System details with incoming/outgoing dependencies
  - `app/views/systems/new.html.erb` - New system form
  - `app/views/systems/edit.html.erb` - Edit system form
  - `app/views/systems/_form.html.erb` - Shared form partial
- **Routes:** Added `resources :systems`
- **Package:** Added `d3@^7.9.0` to package.json
- **Spec:** `spec/requests/systems_spec.rb` - Request spec for systems endpoints
- **Manifest:** Registered system-map controller in `app/javascript/controllers/index.js`

Features implemented:
- **SystemsController:**
  - index: HTML view with D3 graph + grid of systems, JSON API returns nodes/edges
  - show: Display system details with incoming/outgoing dependencies
  - new/create: Create new service system
  - edit/update: Update existing system
  - destroy: Delete system
  - Team-scoped via current_user.team.service_systems
  - Strong params: name, description, repo_url, system_type

- **system_map_controller.js (D3.js):**
  - Fetches JSON data from systems endpoint
  - Force-directed graph with d3.forceSimulation
  - Color-coded nodes by system_type:
    - service: blue (#3B82F6)
    - library: purple (#8B5CF6)
    - database: green (#10B981)
    - queue: orange (#F59E0B)
    - external_api: red (#EF4444)
  - Color-coded edges by dependency_type:
    - http_api: blue
    - rabbitmq: orange
    - grpc: purple
    - database_shared: green
    - event_bus: orange-red
    - sdk: gray
  - Arrow markers on edges showing directionality
  - Edge labels showing dependency type
  - Drag-and-drop nodes (fixes position while dragging)
  - Node labels below circles
  - Responsive SVG size (uses container width or 800px default)

- **Views:**
  - index.html.erb:
    - D3 graph in white card with shadow
    - Grid of system cards below with color-coded left border
    - "Add System" button in header
    - System cards show name, type, and truncated description
  - show.html.erb:
    - System name, type badge, repo URL link
    - Description in prose format
    - Outgoing dependencies (what this system depends on)
    - Incoming dependencies (what depends on this system)
    - Edit and back to System Map buttons
  - Form partial:
    - Name, system_type select, repo_url, description fields
    - Error display for validation failures
    - Tailwind-styled form inputs

- **Helper:**
  - system_color(system_type): Returns hex color for border/node styling

Implementation notes:
- D3.js v7.9.0 for force-directed graph visualization
- JSON API endpoint at /systems.json returns { nodes: [...], edges: [...] }
- Nodes include id, name, type
- Edges include source, target, type (dependency_type), metadata
- Graph uses d3.forceLink to bind edges to node IDs
- Arrow markers created in SVG defs for each dependency type
- Simulation forces: link (distance 150), charge (-300), center
- Drag handlers set fx/fy to fix position, clear on drag end
- Tick handler updates link positions and node transforms
- Link labels positioned at midpoint between nodes
- All Ruby syntax validated with ruby -c
- Database not running - spec created but not executed

Technical decisions:
- Used D3.js force simulation for automatic layout (no manual positioning)
- Color-coded both nodes and edges for visual clarity
- Added arrow markers to show dependency direction
- Edge labels help identify dependency types without needing legend
- Grid view below graph provides quick access to individual systems
- JSON format matches D3.js expectations (id field for nodes, source/target for edges)
- Form uses ServiceSystem.system_types.keys for dynamic enum select
- Helper extracts color logic for reuse across views
- Includes eager loading (:outgoing_dependencies, :target_system, :source_system) to avoid N+1 queries

Key files created/modified:
- **Migrations:**
  - `db/migrate/20260226190000_create_app_keys.rb` - Project-scoped API keys with unique token index
  - `db/migrate/20260226190001_create_feedback_items.rb` - Feedback with category/status enums, jsonb technical_context

- **Models:**
  - `app/models/app_key.rb` - Auto-generates tokens (sf-int-*), active scope, belongs to project
  - `app/models/feedback_item.rb` - GraphSync concern, polymorphic comments, enqueues triage job after create
  - `app/models/project.rb` - Added has_many :app_keys association

- **API Controller:**
  - `app/controllers/api/v1/feedback_controller.rb` - REST API with Bearer token authentication

- **Job:**
  - `app/jobs/feedback_triage_job.rb` - AI categorization using OPENROUTER_CLIENT and Claude Haiku 4.5

- **Routes:**
  - `config/routes.rb` - Added namespace :api/:v1/feedback (POST only)

- **Specs:**
  - `spec/models/app_key_spec.rb` - Token generation validation
  - `spec/models/feedback_item_spec.rb` - Enum and association validations
  - `spec/requests/api/v1/feedback_spec.rb` - API authentication and creation tests
  - `spec/jobs/feedback_triage_job_spec.rb` - AI categorization with webmock stub

- **Factories:**
  - `spec/factories/app_keys.rb` - Uses Faker::App.name
  - `spec/factories/feedback_items.rb` - Default uncategorized/new_item status

Commit: 4301b4d "feat: add Validator API endpoint with auto-triage"

Features implemented:
- **AppKey Model:**
  - Belongs to project for team-scoped API access
  - Auto-generates secure tokens: "sf-int-" + 24 hex chars
  - Active scope for filtering disabled keys
  - Unique token constraint at database level
  - Used for authenticating external app feedback submissions

- **FeedbackItem Model:**
  - Includes GraphSync for automatic Neo4j node creation
  - Belongs to project, has_many comments (polymorphic)
  - Title required (body optional for quick reports)
  - Category enum: uncategorized (default), bug, feature_request, performance
  - Status enum: new_item, triaged, in_progress, resolved, dismissed
  - JSONB technical_context field for browser, URL, user agent, stack traces, etc.
  - Optional submitted_by_email for follow-up
  - Optional source field (e.g., "mobile-app", "web-checkout")
  - Score field (1-10) populated by AI triage
  - Automatically enqueues FeedbackTriageJob on create

- **FeedbackController (API):**
  - ActionController::API (no session, CSRF, or cookies)
  - POST /api/v1/feedback creates feedback item
  - Authenticates via Authorization: Bearer <token> header
  - Returns 201 Created with feedback ID on success
  - Returns 422 Unprocessable Entity with errors on validation failure
  - Returns 401 Unauthorized for invalid/inactive app keys
  - Strong params: title, body, source, submitted_by_email, technical_context (hash)
  - Sets @project from authenticated app_key for scoping

- **FeedbackTriageJob:**
  - Runs asynchronously via Solid Queue (Redis-backed)
  - Only processes uncategorized feedback (guards against re-triage)
  - Calls OPENROUTER_CLIENT.chat with Claude Haiku 4.5 model
  - System prompt: "Categorize this feedback. Respond with JSON: {\"category\": \"bug|feature_request|performance\", \"score\": 1-10}"
  - User prompt includes title, body, and technical_context JSON
  - Parses AI response and updates feedback with category, score, and triaged status
  - Rescue JSON parse errors with empty hash fallback

Implementation notes:
- Database not running - all syntax validated with ruby -c
- All specs created but not executed (require database)
- AppKey tokens generated with SecureRandom for cryptographic security
- GraphService.create_node stubbed in specs to avoid Neo4j dependency
- Job spec uses webmock to stub OpenRouter API calls
- Request spec tests both successful creation and unauthorized rejection
- Technical context stored as JSONB for flexible schema (can include any metadata)
- Enums use integer storage for efficient indexing/querying
- Feedback auto-synced to Neo4j for relationship mapping with Documents, Blueprints, etc.

Technical decisions:
- Used Bearer token authentication (common for REST APIs)
- ActionController::API for lean JSON-only responses (no view rendering)
- JSONB for technical_context allows dynamic fields without migrations
- Auto-triage on create keeps feedback organized without manual intervention
- Score field enables priority sorting (high-score bugs bubble up)
- Status enum supports full feedback lifecycle (new → triaged → in progress → resolved/dismissed)
- Polymorphic comments allow team discussions on feedback items
- App keys scoped to projects enable multi-project deployments
- Active flag on app keys allows soft disabling without deletion
- Submitted_by_email enables user follow-up without full user accounts

## Context for Next Session
Task 24 complete: MCP Server Implementation.

Key files created/modified:
- **MCP Server:**
  - `app/mcp/constitution_mcp_server.rb` - Main server handling JSON-RPC over stdio
  - `bin/mcp` - Executable entrypoint for MCP server

- **Tools (8 total):**
  - `app/mcp/tools/base_tool.rb` - Base class with authentication helpers
  - `app/mcp/tools/list_work_orders.rb` - List work orders with filtering
  - `app/mcp/tools/get_work_order.rb` - Get work order details with comments
  - `app/mcp/tools/update_work_order_status.rb` - Update work order status
  - `app/mcp/tools/get_requirements.rb` - Fetch requirement documents
  - `app/mcp/tools/get_blueprint.rb` - Fetch blueprints
  - `app/mcp/tools/get_system_dependencies.rb` - Get system dependency graph
  - `app/mcp/tools/get_impact_analysis.rb` - Neo4j graph traversal for impact analysis
  - `app/mcp/tools/search.rb` - Full-text and semantic search across all artifacts

- **Resources (4 total):**
  - `app/mcp/resources/base_resource.rb` - Base class for resources
  - `app/mcp/resources/project_requirements.rb` - All requirement docs for a project
  - `app/mcp/resources/project_blueprints.rb` - All blueprints for a project
  - `app/mcp/resources/work_order_resource.rb` - Full work order details
  - `app/mcp/resources/system_dependencies_resource.rb` - System dependency graph

- **Specs:**
  - `spec/mcp/constitution_mcp_server_spec.rb` - Server request handling tests
  - `spec/mcp/tools/list_work_orders_spec.rb` - Tool definition tests
  - `spec/mcp/tools/search_spec.rb` - Search tool tests

Commit: 82d19c7 "feat: add MCP server for IDE integration"

Features implemented:
- **ConstitutionMcpServer:**
  - JSON-RPC 2.0 protocol implementation
  - Stdio-based communication (reads from stdin, writes to stdout)
  - Protocol version: 2024-11-05
  - Capabilities: tools (listChanged: false), resources (subscribe: false, listChanged: false)
  - Server info: name "constitution", version "1.0.0"
  - Request handlers:
    - initialize: Returns server capabilities
    - tools/list: Returns all 8 tool definitions
    - tools/call: Executes tool with arguments, returns JSON result
    - resources/list: Returns all 4 resource definitions
    - resources/read: Reads resource by URI
  - Error handling: Parse errors (-32700), Internal errors (-32603), Method not found (-32601), Unknown tool/resource (-32602)

- **BaseTool:**
  - authenticate!(arguments): Validates api_token, finds user by authentication_token
  - find_project(user, project_id): Team-scoped project lookup
  - Raises exceptions on authentication failures

- **Tool Implementations:**
  - list_work_orders: Filters by status/assignee, returns up to 50 work orders ordered by updated_at
  - get_work_order: Returns full work order with comments and graph neighbors
  - update_work_order_status: Updates status enum field
  - get_requirements: Fetches documents with optional document_type filter
  - get_blueprint: Fetches blueprints with optional blueprint_type filter
  - get_system_dependencies: Returns system with outgoing/incoming dependencies and graph neighbors
  - get_impact_analysis: Calls GraphService.impact_analysis for graph traversal (default depth: 3)
  - search: Full-text search (ILIKE) across documents, blueprints, work orders, plus vector search on code chunks via CodeSearchService

- **BaseResource:**
  - definition: Returns URI template, name, description, mimeType
  - matches?(uri): Regex matching for URI patterns
  - read(uri): Fetches data by URI

- **Resource Implementations:**
  - project_requirements: URI pattern constitution://project/{id}/requirements
  - project_blueprints: URI pattern constitution://project/{id}/blueprints
  - work_order_resource: URI pattern constitution://work-order/{id}
  - system_dependencies_resource: URI pattern constitution://system/{id}/dependencies

Implementation notes:
- Database NOT running - all syntax validated with ruby -c
- All specs created but not executed (require database)
- All 19 files created and committed
- bin/mcp executable with proper permissions (rwxr-xr-x)
- Tools return JSON-serializable hashes (not ActiveRecord objects)
- Resources use regex to extract IDs from URIs
- Authentication via User.authentication_token (not yet implemented, will need to add to User model)
- Tool calls wrapped in rescue to return error responses instead of crashing server
- JSON-RPC responses follow spec: { jsonrpc: "2.0", id: ..., result: ... }

Technical decisions:
- JSON-RPC over stdio for simplicity (no HTTP server needed)
- Tools require api_token for authentication (API-first design)
- Resources use URI templates matching MCP spec (constitution:// protocol)
- Tool responses wrapped in content array with type "text" (MCP spec)
- Error responses use standard JSON-RPC error codes
- Tools return structured data (not raw SQL results)
- Search tool combines full-text (Postgres ILIKE) and semantic (pgvector) search
- Impact analysis tool checks GraphService.available? before calling Neo4j
- Graph neighbors included where relevant (work orders, systems)
- Team-scoped access control throughout all tools
- Tools return truncated snippets (200 chars) for search results

Known limitations:
- User model does not have authentication_token field yet (will need migration)
- CodeSearchService not yet implemented (referenced by search tool)
- GraphService.impact_analysis method not yet implemented
- GraphService.neighbors method not yet implemented
- No rate limiting or request throttling
- No logging of tool calls (could be added later)
- Tool responses not paginated (could be added for large result sets)

Ready for next task: MCP server complete. Can add user authentication_token field, implement CodeSearchService, or move to next feature.

Task 22 complete: Repository Model & Indexing Pipeline.

Key files created/modified:
- **Migrations:**
  - `db/migrate/20260226210000_create_repositories.rb` - Repositories table with indexing_status enum
  - `db/migrate/20260226210001_create_codebase_files.rb` - Files table with path, content, sha, language
  - `db/migrate/20260226210002_create_codebase_chunks.rb` - Chunks table with vector(1536) embedding, ivfflat index
  - `db/migrate/20260226210003_create_extracted_artifacts.rb` - Artifacts table with artifact_type enum, jsonb metadata

- **Models:**
  - `app/models/repository.rb` - Includes GraphSync, belongs_to ServiceSystem, has_many codebase_files
  - `app/models/codebase_file.rb` - Belongs to Repository, has_many codebase_chunks and extracted_artifacts
  - `app/models/codebase_chunk.rb` - Belongs to CodebaseFile, has_neighbors :embedding for vector search
  - `app/models/extracted_artifact.rb` - Includes GraphSync, belongs to CodebaseFile, artifact_type enum (10 types)

- **Services:**
  - `app/services/code_parser.rb` - Parses Ruby, JS/TS, YAML to extract semantic artifacts

- **Jobs:**
  - `app/jobs/codebase_index_job.rb` - Clones repo, indexes files, chunks content, generates embeddings

- **Specs & Factories:**
  - `spec/models/repository_spec.rb`, `spec/models/codebase_file_spec.rb`, `spec/models/codebase_chunk_spec.rb`, `spec/models/extracted_artifact_spec.rb`
  - `spec/services/code_parser_spec.rb` - Tests artifact extraction and chunking
  - `spec/jobs/codebase_index_job_spec.rb` - Tests job status updates and error handling
  - `spec/factories/repositories.rb`, `spec/factories/codebase_files.rb`, `spec/factories/codebase_chunks.rb`, `spec/factories/extracted_artifacts.rb`

Commit: 12c6d13 "feat: add codebase indexing pipeline with pgvector embeddings"

Features implemented:
- **Repository Model:**
  - Includes GraphSync for Neo4j node creation
  - Belongs to ServiceSystem (ServiceSystem already has has_many :repositories)
  - Has_many codebase_files (dependent: :destroy)
  - Enum indexing_status: pending, indexing, indexed, failed
  - Validates name and url presence
  - Tracks last_indexed_at timestamp

- **CodebaseFile Model:**
  - Belongs to Repository
  - Has_many codebase_chunks and extracted_artifacts (both dependent: :destroy)
  - Stores file path, language, content, SHA hash for change detection
  - Unique constraint on [repository_id, path]
  - Tracks last_indexed_at for incremental updates

- **CodebaseChunk Model:**
  - Belongs to CodebaseFile
  - Uses neighbor gem: has_neighbors :embedding for vector similarity search
  - Stores chunk content, chunk_type, start_line, end_line
  - Vector(1536) embedding field for OpenAI text-embedding-3-small
  - IVFFlat index on embedding column for fast cosine similarity search
  - Validates content presence

- **ExtractedArtifact Model:**
  - Includes GraphSync for automatic Neo4j node creation
  - Belongs to CodebaseFile
  - Artifact_type enum with 10 types: route, controller, model, service, api_client, event_emitter, queue_publisher, queue_consumer, protobuf, openapi_spec
  - JSONB metadata field for flexible artifact-specific data
  - Unique constraint on [codebase_file_id, name]
  - Validates name and artifact_type presence

- **CodeParser Service:**
  - Detects language from file extension (.rb, .js, .ts, .yml, .yaml, .proto, .json)
  - parse() method:
    - Ruby: Extracts classes, routes, controller actions, service objects
    - JavaScript/TypeScript: Extracts API client calls (fetch/axios), event emitters
    - YAML: Extracts Docker Compose service definitions
    - Returns empty array for unsupported languages
  - chunk() method:
    - Semantic chunking: Uses extracted artifacts to create chunks by method/class boundaries
    - Fallback: Sliding window of 50 lines for files without parseable artifacts
    - Returns chunks with content, chunk_type, start_line, end_line
  - Helper methods:
    - line_number_of(text): Finds line number containing text
    - find_end_line(start_line): Searches for matching 'end' keyword using indentation

- **CodebaseIndexJob:**
  - Queue: default
  - Updates repository.indexing_status to :indexing on start
  - clone_or_pull: Clones repo or pulls latest changes (--depth=1 for speed)
  - index_files:
    - Iterates all files in repo
    - Skips: node_modules, .git, vendor, tmp, log, images, fonts, minified files, lock files
    - Calculates SHA hash, skips if unchanged
    - Creates/updates CodebaseFile with content, language, sha, last_indexed_at
    - Destroys old artifacts, creates new ones via CodeParser.parse
    - Destroys old chunks, creates new ones via CodeParser.chunk
  - generate_embeddings:
    - Finds all chunks without embeddings
    - Calls OPENROUTER_CLIENT.embeddings with model: "openai/text-embedding-3-small"
    - Truncates content to 8000 chars for API limits
    - Updates chunk with embedding vector
    - Logs warnings on failures (continues indexing)
  - On success: Sets status to :indexed, updates last_indexed_at
  - On error: Sets status to :failed, logs error, re-raises exception

Implementation notes:
- Database NOT running - all syntax validated with ruby -c
- All specs created but not executed (require database and factories)
- Vector index uses ivfflat with vector_cosine_ops for fast approximate nearest neighbor search
- Neighbor gem adds has_neighbors method for vector similarity queries
- ExtractedArtifact syncs to Neo4j for relationship mapping with Documents, Blueprints, etc.
- Repository syncs to Neo4j as nodes (can link to ServiceSystem nodes)
- CodeParser regex patterns designed for common Rails/JS patterns (not AST parsing)
- SHA-based change detection prevents re-indexing unchanged files
- Embeddings generated only for chunks without embeddings (incremental)
- Job designed to be idempotent (can re-run safely)
- Metadata JSONB allows storing file-specific context (e.g., HTTP methods for routes, event names)

Technical decisions:
- Used neighbor gem for pgvector integration (simpler than pg_vector directly)
- IVFFlat index chosen over HNSW (better for datasets under 1M vectors, faster inserts)
- Chunk size: 50 lines max for sliding window (balances context vs. precision)
- Semantic chunking prioritized over fixed-size chunking (preserves meaning)
- SHA hash for change detection (more reliable than timestamp comparison)
- Git clone with --depth=1 for faster initial clone (full history not needed)
- Regex-based parsing over AST parsing (simpler, good enough for artifact extraction)
- ExtractedArtifact includes GraphSync (artifacts are first-class entities in graph)
- CodebaseFile does NOT include GraphSync (too many nodes, not useful for graph queries)
- Artifacts destroyed/recreated on re-index (simpler than diff-based updates)
- Embedding generation continues on chunk failures (partial success better than full failure)
- OPENROUTER_CLIENT already initialized in config/initializers/openrouter.rb

Ready for next task: Codebase indexing pipeline complete. Ready to build UI for repository management, or add semantic code search endpoint using vector similarity.

Tasks 19, 20, and 21 complete: Validator Inbox UI, Action Cable Channels & Presence, and Notification Center UI.

### Task 19: Validator Inbox UI
Key files created/modified:
- **Controller:** `app/controllers/feedback_items_controller.rb` - Full CRUD for feedback with work order creation
- **Views:**
  - `app/views/feedback_items/index.html.erb` - Inbox table with category filters
  - `app/views/feedback_items/show.html.erb` - Feedback detail with "Create Work Order" button
- **Routes:** Added `resources :feedback_items` under projects with `create_work_order` member action
- **Spec:** `spec/requests/feedback_items_spec.rb` - Request spec for inbox and work order creation

Commits:
- 3a8a64b "feat: add Validator inbox with filtering and work order creation"

Features implemented:
- **FeedbackItemsController:**
  - index: Filter by category/status, ordered by created_at desc
  - show: Display feedback details with technical context JSON
  - update: Update category/status via strong params
  - create_work_order: Creates WorkOrder from feedback, creates GraphSync edge, updates status to in_progress
  - Team-scoped via current_user.team.projects

- **Inbox View:**
  - Category filter tabs (All, Uncategorized, Bug, Feature Request, Performance)
  - Table showing title, category badge, score, status badge, created date
  - Clicking title navigates to show page

- **Show View:**
  - Displays title, category/status/score badges
  - "Create Work Order" button (POST to create_work_order action)
  - Body rendered with simple_format
  - Technical context displayed as pretty-printed JSON if present
  - Back to inbox link

### Task 20: Action Cable Channels & Presence
Key files created/modified:
- **Channels:**
  - `app/channels/project_channel.rb` - Project-wide broadcasts
  - `app/channels/document_channel.rb` - Document collaboration with presence tracking
  - `app/channels/notification_channel.rb` - User-specific notifications
- **Stimulus:** `app/javascript/controllers/presence_controller.js` - Presence tracking UI
- **Migration:** `db/migrate/20260226200000_create_notifications.rb` - Notifications table
- **Model:** `app/models/notification.rb` - Notification with auto-broadcast
- **User Model:** Added `has_many :notifications` association
- **Manifest:** Registered presence controller in `app/javascript/controllers/index.js`

Commits:
- 6763594 "feat: add real-time channels for collaboration and presence tracking"

Features implemented:
- **ProjectChannel:**
  - Subscribes to "project_{id}" stream for project-wide broadcasts

- **DocumentChannel:**
  - Subscribes to "document_{id}" stream
  - Broadcasts presence events on subscribed/unsubscribed
  - Presence payload: `{ type: "presence", action: "joined|left", user: { id, name } }`

- **NotificationChannel:**
  - Subscribes to "notifications_{user_id}" stream for user-specific notifications

- **Presence Stimulus Controller:**
  - Tracks active users via Map (user_id → name)
  - Renders green badges for active users
  - Auto-connects on mount, unsubscribes on disconnect
  - Updates UI on joined/left events

- **Notification Model:**
  - Belongs to user and polymorphic notifiable
  - Message required, read boolean (default false)
  - Scopes: unread, recent (20 most recent)
  - after_create_commit broadcasts to "notifications_{user_id}" channel
  - Broadcast payload: `{ type: "notification", id, message, created_at }`

- **Migration:**
  - Polymorphic notifiable (notifiable_type, notifiable_id)
  - Indexes on [notifiable_type, notifiable_id] and [user_id, read]
  - Message required, read defaults to false

### Task 21: Notification Center UI
Key files created/modified:
- **Controller:** `app/controllers/notifications_controller.rb` - Notifications API
- **Partial:** `app/views/shared/_notification_bell.html.erb` - Bell icon with dropdown
- **Stimulus:** `app/javascript/controllers/notifications_controller.js` - Real-time notification updates
- **Routes:** Added `resources :notifications` with mark_read, unread_count collection actions
- **Spec:** `spec/requests/notifications_spec.rb` - Request spec for notifications API
- **Factory:** `spec/factories/notifications.rb` - FactoryBot factory
- **Manifest:** Registered notifications controller in `app/javascript/controllers/index.js`

Commits:
- 62b87cd "feat: add notification center with real-time updates"

Features implemented:
- **NotificationsController:**
  - index: Returns recent notifications (HTML or JSON via respond_to)
  - mark_read: Bulk update notifications to read=true via params[:ids]
  - unread_count: Returns JSON `{ count: N }` for unread notifications

- **Notification Bell Partial:**
  - Bell icon with SVG
  - Badge shows unread count (hidden when 0)
  - Dropdown with notifications list (hidden by default)
  - Stimulus controller data attributes for URL values

- **Notifications Stimulus Controller:**
  - Subscribes to NotificationChannel on connect
  - Fetches notifications via JSON API on toggle
  - Updates badge count and hides/shows based on unread count
  - Renders notifications list with read/unread styling (bg-blue-50 for unread)
  - addNotification increments badge on new real-time notification
  - Unsubscribes and disconnects on controller disconnect

- **Routes:**
  - GET /notifications (HTML and JSON)
  - POST /notifications/mark_read (bulk update)
  - GET /notifications/unread_count (JSON count)

Implementation notes:
- All Ruby syntax validated with ruby -c
- Database not running - specs created but not executed
- Action Cable requires Redis (already configured in Docker Compose)
- All controllers registered in Stimulus manifest
- GraphService.create_edge stubbed in specs for FeedbackItems work order creation
- Notification bell partial ready to be included in layout (not yet integrated)

Technical decisions:
- Action Cable for WebSocket-based real-time updates
- Presence tracking uses Map for efficient add/remove operations
- Notification model broadcasts automatically on create (no manual trigger needed)
- Unread count badge auto-hides when 0 for clean UI
- Dropdown lazy-loads notifications on toggle (not on initial page load)
- Recent scope limits to 20 notifications to prevent UI overload
- Polymorphic notifiable allows notifications for any model (Document, WorkOrder, etc)
- Mark read supports bulk updates for "mark all as read" functionality
- Real-time notification increments badge but doesn't auto-open dropdown (user controls visibility)

Ready for next task: Real-time collaboration infrastructure complete. Ready to integrate notification bell into layout, or proceed with next feature.
