# Engineering State - Constitution

## Last Updated
2026-02-26T14:36:00Z

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
Task 8 complete: Auto-Generate Placeholder Docs on Project Creation implemented.

Key files modified:
- `app/models/project.rb` - Added `self.seed_documents(project, user)` class method that creates two placeholder documents
- `app/controllers/projects_controller.rb` - Added `Project.seed_documents(@project, current_user)` call after successful project save
- `spec/models/project_spec.rb` - Added comprehensive specs for the seed_documents method

Commit: 43d44cb "feat: auto-generate placeholder docs on project creation"

Features implemented:
- When a new project is created, two placeholder documents are auto-generated:
  1. **Product Overview** (document_type: product_overview) with sections: Business Problem, Target Users, Success Criteria
  2. **Technical Requirements** (document_type: technical_requirement) with sections: Authentication & Authorization, Performance, Security
- Documents are created with proper HTML structure using `<h2>` headers and empty `<p>` tags for content
- Both documents are attributed to the creating user via `created_by` association
- Full test coverage for the seed_documents method including document count, titles, content, and associations

Implementation notes:
- Used class method `Project.seed_documents(project, user)` for better testability and separation of concerns
- HTML ampersand properly escaped as `&amp;` in "Authentication & Authorization" section
- Specs verify both documents are created with correct type, title, body content, and user attribution

Note: Database is NOT running, so migrations have not been applied yet. Specs cannot run until database is running and migrations are applied.

Ready for next task: Blueprint, Phase, WorkOrder, and FeedbackItem models.
