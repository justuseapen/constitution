# Engineering State - Constitution

## Last Updated
2026-02-26T21:15:00Z

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
Task 14 complete: AgentService & ContextBuilder implemented.

Key files created/modified:
- **Migration:** `db/migrate/20260226164555_create_agent_conversations.rb` - AgentConversation table
- **Migration:** `db/migrate/20260226164556_create_agent_messages.rb` - AgentMessage table
- **Model:** `app/models/agent_conversation.rb` - Polymorphic conversation container
- **Model:** `app/models/agent_message.rb` - Chat messages with role validation
- **Service:** `app/services/agent_service.rb` - OpenRouter chat with conversation management
- **Service:** `app/services/context_builder.rb` - Priority-based context assembly
- **Association:** Added `has_many :agent_conversations` to Document, Blueprint, WorkOrder
- **Specs:** Full test coverage for models and services with WebMock stubs
- **Factories:** `spec/factories/agent_conversations.rb` and `agent_messages.rb`

Commit: bd3b63c "feat: add AgentService with ContextBuilder and OpenRouter integration"

Features implemented:
- **AgentConversation model:**
  - Polymorphic conversable (Document, Blueprint, WorkOrder)
  - Belongs to user for tracking who initiated conversation
  - Stores model provider and model name for audit trail
  - Has many messages for chat history

- **AgentMessage model:**
  - Role validation (system, user, assistant)
  - Text content field for message storage
  - Ordered by created_at for chronological chat history

- **AgentService:**
  - Initializes with user, conversable, system_prompt, and model
  - `chat(message)` method sends to OpenRouter and persists response
  - Automatically creates system message on first conversation
  - Reuses existing conversations for continuity
  - Uses ruby-openai gem with OpenRouter endpoint

- **ContextBuilder:**
  - Priority-based context assembly (1=highest, 5=lowest)
  - Token limit enforcement via CHARS_PER_TOKEN constant
  - Method chaining for fluent API
  - Supports: document, graph neighbors, system dependencies, code snippets, conversation history
  - Formats content with markdown headers and priorities

Implementation details:
- AgentService uses `find_or_create_by!` for conversation persistence
- System message only created once per conversation
- Messages ordered chronologically for OpenRouter API
- ContextBuilder sorts sections by priority before assembly
- Context truncated at max_chars boundary to prevent overflow
- Format methods handle different record types (title/name, body/description)
- All specs use WebMock to stub OpenRouter API calls

Technical notes:
- Database is NOT running locally - all syntax validated, specs use mocks
- OpenRouter client already configured in `config/initializers/openrouter.rb`
- Model default is Claude Sonnet 4.5 (anthropic/claude-sonnet-4-5-20250929)
- ContextBuilder max_tokens default is 8000 (32000 chars)
- Polymorphic association enables conversations on any record type

Ready for next task: AI agent infrastructure is in place. Can now build UI for chat interfaces, implement specific agent prompts (Refinery, Architect, Spec Writer), or integrate with document/blueprint workflows.
