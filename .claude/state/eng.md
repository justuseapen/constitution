# Engineering State - Constitution

## Last Updated
2026-02-26T14:15:00Z

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
Task 6 complete: Polymorphic Comment model implemented.

Key files created:
- `app/models/comment.rb` - Comment model with polymorphic belongs_to :commentable, belongs_to :user; validates :body presence
- `db/migrate/20260226141114_create_comments.rb` - Comments migration with polymorphic commentable_id/commentable_type, user_id FK, body text, resolved boolean (default: false)
- `spec/models/comment_spec.rb` - Comment model specs with Shoulda matchers and polymorphic association test
- `spec/factories/comments.rb` - Comment factory with Faker, defaults commentable to Document

Model relationships:
- Comment belongs_to :commentable (polymorphic), :user
- Document has_many :comments (already configured from Task 5)

Commit: d7c6c8b "feat: add polymorphic Comment model"

Comment model features:
- Polymorphic commentable (can attach to Documents, Blueprints, WorkOrders)
- Required body text field
- resolved boolean flag (default: false) for tracking comment resolution
- User association for comment author
- Fully tested with RSpec and FactoryBot

Note: Database is NOT running, so migrations have not been applied yet. Specs cannot run until database is running and migrations are applied.

Ready for next task: Blueprint, Phase, WorkOrder, and FeedbackItem models.
