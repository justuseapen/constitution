# Engineering State - Constitution

## Last Updated
2026-02-25T21:23:00Z

## Current Sprint Goal
Initialize Rails 8 application with Docker Compose infrastructure (Postgres, Neo4j, Redis) and core gems

## Active Work
| Task | Status | Branch | Notes |
|------|--------|--------|-------|
| Docker Compose & Rails 8 App Init | Complete | master | Rails 8.1.2 app with Docker Compose created |
| Core Gems & Configuration | Complete | master | All gems installed, RSpec configured |
| User & Team Models with Devise | Complete | master | Authentication setup with model specs, factories |

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
Task 3 complete: User and Team models with Devise authentication setup.

Key files created:
- `app/models/team.rb` - Team model with slug auto-generation, has_many users/projects
- `app/models/user.rb` - User model with Devise auth, role enum (member/admin/owner), belongs_to team
- `spec/models/team_spec.rb` - Team model specs with Shoulda matchers
- `spec/models/user_spec.rb` - User model specs with Shoulda matchers
- `spec/factories/teams.rb` - Team factory with Faker
- `spec/factories/users.rb` - User factory with Faker
- `spec/support/devise.rb` - Devise test helpers for request/system specs
- `config/initializers/devise.rb` - Devise configuration
- `db/migrate/20260225212133_create_teams.rb` - Team migration (name, slug with unique index)
- `db/migrate/20260225212144_devise_create_users.rb` - User migration with Devise fields + name, role (default: 0), team_id

Model relationships:
- Team has_many :users, has_many :projects
- User belongs_to :team, has role enum (member: 0, admin: 1, owner: 2, default: member)

Configuration:
- `spec/rails_helper.rb` - Uncommented support file loading
- `config/routes.rb` - Added devise_for :users

Commit: 12997d2 "feat: add User and Team models with Devise authentication"

Note: Database is NOT running, so migrations have not been applied yet. Specs cannot run until database is running and migrations are applied.

Ready for next task: Amendment, Thread, Position, Argument, Context models and relationships.
