# Engineering State - Constitution

## Last Updated
2026-02-26T17:30:00Z

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
Task 11 complete: WorkOrders Kanban Board with drag-and-drop implemented.

Key files created/modified:
- **Controller:** `app/controllers/work_orders_controller.rb`
- **Views:** `app/views/work_orders/index.html.erb` (kanban board), `show.html.erb`, `new.html.erb`, `edit.html.erb`, `_form.html.erb`, `_work_order_card.html.erb`
- **JavaScript:** `app/javascript/controllers/kanban_controller.js` (Sortable.js integration)
- **Specs:** `spec/requests/work_orders_spec.rb`
- **Routes:** Added `resources :work_orders` nested under projects
- **Dependencies:** Added `sortablejs` to `package.json`
- **Model:** Updated `app/models/work_order.rb` with Turbo Stream broadcast callback

Commit: 3ec60f7 "feat: add kanban board with drag-and-drop via Sortable.js + Turbo"

Features implemented:
- **Kanban board** - Visual board with 5 status columns (backlog, todo, in_progress, review, done)
- **Drag-and-drop** - Sortable.js integration allows dragging work orders between columns
- **Real-time updates** - Turbo Stream broadcasts update cards after changes
- **Full CRUD** - Create, read, update, delete work orders with proper scoping to project and team
- **Work order form** - Complete form with title, status, priority, phase, assignee, description, acceptance criteria, implementation plan
- **Work order card** - Compact card showing title, priority badge, assignee name
- **Show view** - Detailed view with all work order fields formatted
- **JSON API** - Controller responds to JSON for drag-and-drop PATCH requests
- **Request specs** - Full coverage including HTML and JSON responses

Implementation details:
- Controller follows DocumentsController pattern (authenticate_user!, set_project scoping to current_user.team)
- Kanban Stimulus controller creates Sortable instances for each column with shared group "kanban"
- On drag end, controller sends PATCH request with new status and position
- Turbo Stream callback broadcasts to "project_{id}_work_orders" stream
- Views use Tailwind CSS for styling, consistent with existing views
- Form includes collection_select for phases and assignees from current project/team
- Request specs test all CRUD operations plus JSON PATCH for drag-and-drop

Note: Database is NOT running locally, so specs cannot be executed yet. All syntax has been validated. Need to run `npm install` to install sortablejs dependency.

Ready for next task: Can now build on the Planner module (e.g., AI-powered work order generation, phase management UI, etc.).
