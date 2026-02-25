# Constitution — Design Document

**Date:** 2026-02-25
**Status:** Approved

## Overview

Constitution is an AI-native SDLC orchestration platform for internal use. It provides a unified workspace where PMs, designers, engineers, and QA collaborate across the full software lifecycle — from requirements through architecture, planning, and user feedback.

The core thesis: code quality is a function of upstream clarity. The bottleneck in enterprise development isn't writing code — it's decision-making, alignment, and context management. Constitution addresses this by connecting every artifact (requirements, blueprints, work orders, code, feedback) in a knowledge graph that detects drift and maintains coherence.

The goal is to replace Jira and fragmented documentation tools with a single system that models the full lifecycle.

## Users

A team of 5+ including PMs, engineers, designers, and QA. Multi-user collaboration with real-time editing, presence, and notifications.

## Tech Stack

- **Framework:** Ruby on Rails 8 (monolith)
- **Real-time:** Hotwire (Turbo Streams + Stimulus) + Action Cable
- **Primary database:** PostgreSQL 16 with pgvector extension
- **Knowledge graph:** Neo4j 5
- **Cache/pubsub:** Redis 7
- **Background jobs:** Solid Queue
- **Rich text editor:** Tiptap (via jsbundling-rails)
- **AI providers:** OpenRouter (multi-provider model routing)
- **Coding agents:** OpenCode (with MCP integration)
- **Deployment:** Local via Docker Compose (production deployment TBD — Rumble Cloud)

## Architecture: Monolith-First

Single Rails 8 app serving all modules. Chosen for speed of iteration, simplicity of deployment, and because Rails 8's built-in Solid Queue/Cable/Cache reduce infrastructure needs. Can be extracted into services later if needed.

---

## Data Model

### Postgres (Core Data)

```
Users
  - id, email, name, role, avatar, team_id

Teams
  - id, name, slug

Projects
  - id, team_id, name, description, status

# --- Refinery ---

Documents (type: product_overview | feature_requirement | technical_requirement)
  - id, project_id, type, title, body (rich text), status, version
  - created_by, updated_by

DocumentVersions
  - id, document_id, body_snapshot, version_number, created_by, diff_from_previous

Comments
  - id, commentable_type, commentable_id, user_id, body, resolved

# --- Foundry ---

Blueprints (type: foundation | system_diagram | feature_blueprint)
  - id, project_id, type, title, body (rich text), status, version
  - created_by, updated_by

BlueprintVersions (same pattern as DocumentVersions)

# --- Planner ---

Phases
  - id, project_id, name, position

WorkOrders
  - id, project_id, phase_id, title, description, acceptance_criteria
  - status (backlog | todo | in_progress | review | done)
  - assignee_id, priority, position
  - implementation_plan (rich text)

# --- Validator ---

FeedbackItems
  - id, project_id, source, category (bug | feature_request | performance)
  - title, body, technical_context (jsonb), score, status
  - submitted_by_email, browser, device

# --- AI ---

AgentConversations
  - id, conversable_type, conversable_id, user_id
  - model_provider, model_name

AgentMessages
  - id, agent_conversation_id, role (user | assistant | system), content

# --- System Registry ---

Systems
  - id, team_id, name, description, repo_url
  - system_type (service | library | database | queue | external_api)

SystemDependencies
  - id, source_system_id, target_system_id
  - dependency_type (http_api | rabbitmq | grpc | database_shared | event_bus | sdk)
  - description, metadata (jsonb)

# --- Codebase Indexing ---

Repositories
  - id, system_id, url, branch, access_token_encrypted
  - last_indexed_at, index_status

CodebaseFiles
  - id, repository_id, path, language, content_hash, last_modified_at

CodebaseChunks
  - id, codebase_file_id, content, chunk_type (function | class | route | schema | config)
  - embedding (vector(1536)), start_line, end_line

ExtractedArtifacts
  - id, repository_id, artifact_type (api_endpoint | queue_publisher | queue_consumer | db_schema | openapi_spec)
  - name, metadata (jsonb)
```

### Neo4j (Knowledge Graph)

Every Postgres record that participates in the graph gets a corresponding Neo4j node with its Postgres ID. Edges represent typed relationships:

```
(Document)-[:DEFINES_FEATURE]->(Blueprint)
(Blueprint)-[:IMPLEMENTED_BY]->(WorkOrder)
(WorkOrder)-[:TRACES_TO]->(Document)
(FeedbackItem)-[:RELATES_TO]->(Document|Blueprint|WorkOrder)
(Document)-[:DEPENDS_ON]->(Document)
(Blueprint)-[:DEPENDS_ON]->(Blueprint)
(System)-[:CALLS_API {endpoints: [...]}]->(System)
(System)-[:PUBLISHES_TO {exchange: "...", routing_key: "..."}]->(System)
(System)-[:CONSUMES_FROM {queue: "..."}]->(System)
(System)-[:READS_FROM]->(System)
```

A `GraphSync` concern on ActiveRecord models keeps Neo4j nodes in sync via after_commit callbacks. Drift detection runs as a periodic background job that traverses the graph looking for stale edges.

---

## Modules

### Refinery (Requirements Layer)

Transforms raw ideas, artifacts, and feedback into structured, unambiguous requirements.

**Document types:**
- Product Overview Documents — strategic context
- Feature Requirements Documents — individual feature specs with testable acceptance criteria
- Technical Requirements Documents — cross-cutting concerns (auth, security, performance)

**Capabilities:**
- AI-guided Q&A for requirement gathering (Refinery Agent in chat sidebar)
- Reverse-engineering mode: analyze existing codebases and draft requirements
- Quality review: flags ambiguity, gaps, conflicts, missing acceptance criteria
- Feature organization suggestions (split, merge, restructure)
- Drift monitoring between requirements and blueprints
- Collaborative editing with comments, @mentions, versioning, diff comparison
- Import/export: .md, .docx, .pdf

**Workflow:**
1. Project creation auto-generates placeholder Product Overview and Technical Requirements docs
2. Definition phase: agent-guided Q&A captures intent
3. Feature creation: collaborative spec writing with agent assistance

### Project Import / Existing Project Onboarding

When creating a project, users choose "Start fresh" or "Import existing project."

**Import sources:**
- **Git repository** — connect a repo, system indexes codebase, AI reverse-engineers requirements and architecture
- **Jira import** — pull existing epics/stories/tasks as work orders, preserving hierarchy and status mapping
- **Document upload** — bulk upload existing specs (.md, .docx, .pdf), AI parses into Refinery documents
- **Manual entry** — paste/type with agent assistance

After import, the Refinery Agent runs a gap analysis flagging what's missing, ambiguous, or inconsistent. Imported artifacts get Neo4j nodes immediately.

### Foundry (Architecture Layer)

Transforms product requirements into actionable technical blueprints with bidirectional alignment.

**Blueprint types:**
- Foundations — project-wide technical decisions (architecture, tech stack, security, deployment)
- System Diagrams — visual architecture via Mermaid with live preview
- Feature Blueprints — detailed specs per feature (APIs, UI behavior, data models, testing), auto-linked to Refinery's feature hierarchy

**Capabilities:**
- Structured edit suggestions as color-coded inline diffs (accept/reject)
- Full project context awareness (all blueprints, codebase index, work orders)
- Mermaid diagram generation and updates
- Gap and conflict detection across blueprints
- Template system (common and org-specific)
- Drift alerts when linked requirements change

**Workflow:**
1. Template configuration
2. Foundation population (review/refine pre-populated decisions)
3. Feature blueprint completion

### Planner (Work Management — Jira Replacement)

Converts architectural blueprints into executable, traceable work orders.

**Work order structure:**
- Metadata: ID, title, status, assignees, phase, priority
- Rich description with acceptance criteria and scope boundaries
- Knowledge graph links to upstream requirements/blueprints
- Optional implementation plan with file-level guidance
- Activity feed with threaded comments

**Views:**
- Kanban board (drag-and-drop via Sortable.js + Turbo)
- Table/list view
- Phase-based grouping with collapsible sections

**Population methods:**
- Agent-driven extraction from blueprints (feature-slice or specialist-oriented strategies)
- Manual creation with local draft caching

**Status workflow:** Backlog -> Todo -> In Progress -> Review -> Done

**Filters:** assignee, status, phase, priority, linked feature

### Validator (Feedback Loop)

Transforms user feedback into actionable development tasks, closing the loop from production back to planning.

**Pipeline:**
1. Collect — lightweight REST API (authenticated via app keys `sf-int-xxxxx`)
2. Enrich — auto-attach browser, device, session data, recent code changes
3. Categorize — AI classifies type and assigns priority score
4. Notify — Slack webhooks for high-priority items
5. Generate — one-click "Create Work Order" with pre-filled context and Neo4j link

**Validator Inbox:** real-time filterable/searchable dashboard of all feedback.

### System Registry & Dependency Mapping

Models the team's microservice architecture, including HTTP and RabbitMQ communication.

**System map view:** visual graph (D3.js or Mermaid) showing all services, communication channels, and dependency direction.

**Capabilities:**
- Projects link to Systems; work orders tagged with affected systems
- Impact analysis: changing an API contract or message schema triggers graph traversal showing affected downstream services
- Auto-discovery: codebase indexing scans for OpenAPI specs, RabbitMQ declarations, HTTP client calls, protobuf/schema files; proposes dependency edges for confirmation
- Cross-system drift detection: flags contract mismatches between producer and consumer blueprints
- Foundation blueprints scoped per-system or cross-system
- Feature blueprints spanning multiple systems get auto-populated "cross-system impact" sections

---

## AI Agent Layer

### AgentService

A unified service abstracts all LLM interactions:
- Provider routing via OpenRouter (model selection per task type)
- Conversation persistence in Postgres
- Streaming responses via Turbo Streams
- Context assembly pipeline

### Context Assembly

```ruby
context = ContextBuilder.new(project)
  .add_document(current_document)
  .add_graph_neighbors(current_document)   # from Neo4j
  .add_system_dependencies(affected_systems)
  .add_codebase_snippets(relevant_files)
  .add_conversation_history(conversation)
  .build
```

Prioritization: current artifact > direct graph neighbors > system context > codebase snippets. Truncates intelligently within token limits.

### Agent Specializations

| Agent | Trigger Points | Key Actions |
|-------|---------------|-------------|
| Refinery Agent | Document editor sidebar | Guided Q&A, gap analysis, quality review, feature suggestions, reverse-engineer from code |
| Foundry Agent | Blueprint editor sidebar | Draft blueprints, structured edit suggestions, Mermaid generation, drift resolution |
| Planner Agent | Work order views | Decompose blueprints into tasks, batch edits, implementation plan refinement |
| Validator Agent | Feedback inbox | Auto-categorize, priority score, generate work orders from feedback |
| System Agent | System map view | Auto-discover dependencies, impact analysis, contract mismatch detection |

Each agent is the same underlying AgentService with a different system prompt and context assembly strategy.

### Background AI Jobs (Solid Queue)

- Drift detection — periodic graph traversal comparing artifact versions
- Feedback triage — auto-categorize and score new feedback on ingest
- Dependency discovery — scan indexed codebases for API calls, queue declarations, schema files

### OpenCode Integration

Work orders include an "Open in OpenCode" action that pre-loads the implementation plan + linked requirements/blueprints as context via the MCP server.

---

## Real-Time Collaboration

### Turbo Streams + Action Cable

Every collaborative surface broadcasts changes in real-time.

**Features:**
- Document/blueprint editing: Tiptap with collaboration extension. Visible cursors per user. Block-level last-write-wins conflict resolution
- Comments & mentions: instant appearance for all viewers, @mentions trigger notifications
- Work order board: drag-and-drop changes broadcast immediately
- Agent chat: streaming LLM responses visible to all users viewing the same artifact
- Presence indicators: "Justus is viewing this document" avatars
- Notification center: bell icon with real-time counter for drift alerts, mentions, assignments, feedback

### Channel Structure

```
ProjectChannel (project_id)
  → document updates, new comments, work order changes

DocumentChannel (document_id)
  → collaborative editing, cursor positions, inline comments

NotificationChannel (user_id)
  → personal notifications, mentions, assignments
```

### Offline/Conflict Handling

Edits queue locally if disconnected, sync on reconnect. Block-level last-write-wins with "conflict detected" toast showing both versions if same block edited by two users.

---

## Codebase Indexing

### Pipeline

1. Clone/pull repo into temporary working directory (background job)
2. Parse file tree — structural map of directories, files, types
3. Extract key artifacts (language-aware):
   - API endpoints (routes, controllers)
   - Message queue declarations (RabbitMQ publishers/consumers, exchange/queue bindings)
   - Database schemas (migrations, schema files)
   - OpenAPI/Swagger specs
   - Protobuf/Avro/JSON Schema definitions
   - Environment variables and config
   - Test files
4. Generate embeddings — chunk code, embed via OpenRouter, store in Postgres with pgvector
5. Link to Systems — extracted artifacts auto-populate Neo4j dependency edges

### Sync

- Webhook-triggered re-index on push (GitHub/GitLab webhooks) or manual trigger
- Incremental indexing — only re-processes changed files based on content hash
- Re-index updates Neo4j edges and flags new drift

### Agent Usage

- Refinery: "This codebase already has a PaymentService — should we document it?"
- Foundry: "Based on routes in orders_controller.rb, here's a draft API blueprint"
- Planner: "This work order should touch app/services/payment_service.rb lines 45-80"
- System: "Found BunnyPublisher.publish('order.created') in Order Service and subscribe('order.created') in Notification Service — confirming dependency"

---

## MCP Server

Constitution exposes an MCP server for IDE integration (Claude Code, OpenCode, any MCP-compatible tool).

### Tools

```
constitution.list_work_orders(project, assignee, status)
constitution.get_work_order(id)
constitution.update_work_order_status(id, status)
constitution.get_requirements(project, feature)
constitution.get_blueprint(project, feature)
constitution.get_system_dependencies(system)
constitution.get_impact_analysis(system, change_description)
constitution.search(project, query)
```

### Resources

```
constitution://project/{id}/requirements
constitution://project/{id}/blueprints
constitution://work-order/{id}
constitution://system/{id}/dependencies
```

---

## Local Development Setup

Docker Compose for v1:

```yaml
services:
  web:        # Rails 8 (Puma)
  postgres:   # Primary database + pgvector
  neo4j:      # Knowledge graph
  redis:      # Action Cable + caching
  worker:     # Solid Queue background jobs
```

```bash
git clone <repo>
docker compose up
bin/rails db:setup
# Visit localhost:3000
```

**Dependencies:**
- Ruby 3.3+ / Rails 8
- PostgreSQL 16 with pgvector
- Neo4j 5
- Redis 7
- Node (for Tiptap assets via jsbundling-rails)
