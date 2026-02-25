# Engineering State - Constitution

## Last Updated
2026-02-25T21:35:00Z

## Current Sprint Goal
Initialize Rails 8 application with Docker Compose infrastructure (Postgres, Neo4j, Redis) and core gems

## Active Work
| Task | Status | Branch | Notes |
|------|--------|--------|-------|
| Docker Compose & Rails 8 App Init | Complete | master | Rails 8.1.2 app with Docker Compose created |
| Core Gems & Configuration | Complete | master | All gems installed, RSpec configured |
| User & Team Models with Devise | Complete | master | Authentication setup with model specs, factories |
| Project Model & CRUD | Complete | master | Project model with full CRUD, team-scoped |

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
Task 4 complete: Project model with full CRUD functionality.

Key files created:
- `app/models/project.rb` - Project model with belongs_to :team, has_many associations (documents, blueprints, phases, work_orders, feedback_items), name validation, status enum (active: 0, archived: 1)
- `db/migrate/20260225213508_create_projects.rb` - Project migration with name, description, status (default: 0), team_id foreign key
- `spec/models/project_spec.rb` - Project model specs with Shoulda matchers
- `spec/factories/projects.rb` - Project factory with Faker
- `app/controllers/projects_controller.rb` - Full CRUD controller scoped to current_user.team.projects
- `app/views/projects/index.html.erb` - Projects list view with Tailwind CSS
- `app/views/projects/show.html.erb` - Project detail view
- `app/views/projects/new.html.erb` - New project form
- `app/views/projects/edit.html.erb` - Edit project form
- `app/views/projects/_form.html.erb` - Shared form partial
- `spec/requests/projects_spec.rb` - Request specs for CRUD actions
- `config/routes.rb` - Added resources :projects and root "projects#index"

Model relationships:
- Project belongs_to :team
- Project has_many :documents, :blueprints, :phases, :work_orders, :feedback_items (all dependent: :destroy)
- Team already has_many :projects

Commit: 3cd2a78 "feat: add Project model with CRUD, scoped to team"

Note: Database is NOT running, so migrations have not been applied yet. Specs cannot run until database is running and migrations are applied.

Ready for next task: Document, Blueprint, Phase, WorkOrder, FeedbackItem models and relationships.
