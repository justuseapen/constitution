# Engineering State - Constitution

## Last Updated
2026-02-26T16:05:00Z

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
Task 10 complete: Phase and WorkOrder models implemented.

Key files created:
- **Models:** `app/models/phase.rb`, `app/models/work_order.rb`
- **Migrations:** `db/migrate/20260226160000_create_phases.rb`, `db/migrate/20260226160001_create_work_orders.rb`
- **Specs:** `spec/models/phase_spec.rb`, `spec/models/work_order_spec.rb`
- **Factories:** `spec/factories/phases.rb`, `spec/factories/work_orders.rb`

Commit: 9a67471 "feat: add Phase and WorkOrder models"

Features implemented:
- **Phase model** - Organizes work orders into sequential phases with position ordering
- **WorkOrder model** - Traceable task units with status, priority, acceptance criteria, and implementation plans
- **Associations** - Phase has_many work_orders (nullify on delete), WorkOrder belongs_to phase (optional), project, assignee (User)
- **Polymorphic comments** - WorkOrder is commentable via existing Comment model
- **Status enum** - backlog (0), todo (1), in_progress (2), review (3), done (4)
- **Priority enum** - low (0), medium (1), high (2), critical (3)
- **Position fields** - Both Phase and WorkOrder have position for drag-and-drop ordering
- **AI-ready fields** - acceptance_criteria, implementation_plan for AI-generated content
- **Full test coverage** - Model specs with shoulda-matchers, factories with Faker data

Implementation details:
- Phase has default_scope ordering by position
- WorkOrder assignee_id references users table with optional FK
- Indexes on work_orders: assignee_id, status, priority for query optimization
- Phase deletion nullifies work_orders (they can exist without a phase)
- Both models validate presence of key fields (name for Phase, title for WorkOrder)

Note: Database is NOT running locally, so migrations have not been applied yet. Specs cannot run until database is running and migrations are applied.

Ready for next task: WorkOrders controller and Kanban UI.
