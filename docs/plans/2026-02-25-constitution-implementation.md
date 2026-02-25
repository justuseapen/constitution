# Constitution Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build Constitution, an AI-native SDLC orchestration platform with four modules (Refinery, Foundry, Planner, Validator), a system registry, knowledge graph, real-time collaboration, and MCP server.

**Architecture:** Rails 8 monolith with Hotwire/Turbo for real-time, PostgreSQL + pgvector for core data and semantic search, Neo4j for the knowledge graph, OpenRouter for AI agents, Tiptap for rich text editing. Docker Compose for local dev.

**Tech Stack:** Ruby 3.3+, Rails 8, PostgreSQL 16 + pgvector, Neo4j 5, Redis 7, Solid Queue, Tiptap, Sortable.js, Mermaid.js, D3.js, OpenRouter API

**Design doc:** `docs/plans/2026-02-25-constitution-design.md`

---

## Phase 1: Project Skeleton & Infrastructure

Gets Docker Compose running with Rails, Postgres, Neo4j, Redis. Authentication and team/project CRUD. The foundation everything else builds on.

---

### Task 1: Docker Compose & Rails 8 App Init

**Files:**
- Create: `docker-compose.yml`
- Create: `Dockerfile`
- Create: `Dockerfile.dev`
- Create: `.dockerignore`
- Create: `bin/docker-entrypoint`
- Create: `.env.example`

**Step 1: Create docker-compose.yml**

```yaml
services:
  web:
    build:
      context: .
      dockerfile: Dockerfile.dev
    ports:
      - "3000:3000"
    volumes:
      - .:/rails
      - bundle:/usr/local/bundle
      - node_modules:/rails/node_modules
    depends_on:
      postgres:
        condition: service_healthy
      neo4j:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      - DATABASE_URL=postgres://constitution:constitution@postgres:5432/constitution_development
      - NEO4J_URL=bolt://neo4j:7687
      - NEO4J_USERNAME=neo4j
      - NEO4J_PASSWORD=constitution_dev
      - REDIS_URL=redis://redis:6379/0
      - RAILS_ENV=development
    env_file:
      - .env
    stdin_open: true
    tty: true

  postgres:
    image: pgvector/pgvector:pg16
    environment:
      POSTGRES_USER: constitution
      POSTGRES_PASSWORD: constitution
      POSTGRES_DB: constitution_development
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U constitution"]
      interval: 5s
      timeout: 5s
      retries: 5

  neo4j:
    image: neo4j:5
    environment:
      NEO4J_AUTH: neo4j/constitution_dev
      NEO4J_PLUGINS: '["apoc"]'
    ports:
      - "7474:7474"
      - "7687:7687"
    volumes:
      - neo4j_data:/data
    healthcheck:
      test: ["CMD", "neo4j", "status"]
      interval: 10s
      timeout: 10s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5

  worker:
    build:
      context: .
      dockerfile: Dockerfile.dev
    command: bin/jobs
    volumes:
      - .:/rails
      - bundle:/usr/local/bundle
    depends_on:
      postgres:
        condition: service_healthy
      neo4j:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      - DATABASE_URL=postgres://constitution:constitution@postgres:5432/constitution_development
      - NEO4J_URL=bolt://neo4j:7687
      - NEO4J_USERNAME=neo4j
      - NEO4J_PASSWORD=constitution_dev
      - REDIS_URL=redis://redis:6379/0
      - RAILS_ENV=development
    env_file:
      - .env

volumes:
  postgres_data:
  neo4j_data:
  redis_data:
  bundle:
  node_modules:
```

**Step 2: Create .env.example**

```
OPENROUTER_API_KEY=your_key_here
```

**Step 3: Generate the Rails 8 app**

Run (outside Docker, locally):
```bash
gem install rails
rails new . --database=postgresql --javascript=esbuild --css=tailwind --skip-test --skip-system-test --force
```

Note: We use `--skip-test` because we'll add RSpec manually. `--force` overwrites existing files.

**Step 4: Create Dockerfile.dev**

```dockerfile
FROM ruby:3.3-slim

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential curl git libpq-dev node-gyp pkg-config python-is-python3 \
    libjemalloc2 libvips && \
    rm -rf /var/lib/apt/lists/*

# Install Node.js 20
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g yarn

WORKDIR /rails

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY package.json yarn.lock* ./
RUN yarn install

COPY . .

EXPOSE 3000
CMD ["bin/dev"]
```

**Step 5: Create bin/docker-entrypoint**

```bash
#!/bin/bash
set -e

if [ -f tmp/pids/server.pid ]; then
  rm tmp/pids/server.pid
fi

exec "${@}"
```

Run: `chmod +x bin/docker-entrypoint`

**Step 6: Verify Docker Compose starts**

Run: `docker compose build && docker compose up -d`
Expected: All 4 services healthy. Visit http://localhost:3000 and see Rails welcome page.

**Step 7: Commit**

```bash
git add -A
git commit -m "feat: initialize Rails 8 app with Docker Compose (Postgres, Neo4j, Redis)"
```

---

### Task 2: Core Gems & Configuration

**Files:**
- Modify: `Gemfile`
- Create: `config/initializers/neo4j.rb`
- Create: `config/initializers/openrouter.rb`
- Create: `spec/rails_helper.rb`
- Create: `spec/spec_helper.rb`
- Create: `.rspec`

**Step 1: Add gems to Gemfile**

Append to `Gemfile`:
```ruby
# Neo4j
gem "activegraph", "~> 11.5"
gem "neo4j-ruby-driver", "~> 4.4"

# Authentication
gem "devise", "~> 4.9"

# Background jobs (already in Rails 8 via solid_queue)
# gem "solid_queue" # already included

# AI
gem "ruby-openai", "~> 7.0"  # OpenRouter is OpenAI-compatible

# Search
gem "neighbor", "~> 0.4"  # pgvector integration

# Rich text
gem "action_text"  # already in Rails 8

# Authorization
gem "pundit", "~> 2.3"

# Serialization
gem "oj", "~> 3.16"

# Testing
group :development, :test do
  gem "rspec-rails", "~> 7.0"
  gem "factory_bot_rails", "~> 6.4"
  gem "faker", "~> 3.4"
  gem "shoulda-matchers", "~> 6.2"
end

group :test do
  gem "database_cleaner-active_record", "~> 2.1"
  gem "webmock", "~> 3.23"
  gem "vcr", "~> 6.2"
end
```

**Step 2: Run bundle install**

Run: `docker compose run --rm web bundle install`

**Step 3: Install RSpec**

Run: `docker compose run --rm web bin/rails generate rspec:install`

**Step 4: Configure .rspec**

```
--require spec_helper
--format documentation
--color
```

**Step 5: Configure spec/rails_helper.rb**

Add to the `RSpec.configure` block:
```ruby
config.include FactoryBot::Syntax::Methods

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
```

**Step 6: Create config/initializers/neo4j.rb**

```ruby
require "neo4j/driver"

NEO4J_DRIVER = Neo4j::Driver::GraphDatabase.driver(
  ENV.fetch("NEO4J_URL", "bolt://localhost:7687"),
  Neo4j::Driver::AuthTokens.basic(
    ENV.fetch("NEO4J_USERNAME", "neo4j"),
    ENV.fetch("NEO4J_PASSWORD", "constitution_dev")
  )
)

at_exit { NEO4J_DRIVER.close }
```

**Step 7: Create config/initializers/openrouter.rb**

```ruby
OPENROUTER_CLIENT = OpenAI::Client.new(
  access_token: ENV.fetch("OPENROUTER_API_KEY", ""),
  uri_base: "https://openrouter.ai/api/v1"
)
```

**Step 8: Enable pgvector extension**

Run: `docker compose run --rm web bin/rails generate migration EnablePgvector`

In the generated migration:
```ruby
class EnablePgvector < ActiveRecord::Migration[8.0]
  def change
    enable_extension "vector"
  end
end
```

Run: `docker compose run --rm web bin/rails db:migrate`

**Step 9: Verify RSpec runs**

Run: `docker compose run --rm web bundle exec rspec`
Expected: 0 examples, 0 failures

**Step 10: Commit**

```bash
git add -A
git commit -m "feat: add core gems (Neo4j, Devise, RSpec, OpenRouter, pgvector)"
```

---

### Task 3: Authentication (Devise)

**Files:**
- Create: `app/models/user.rb`
- Create: `app/models/team.rb`
- Create: migration for teams
- Create: migration for users (via Devise)
- Create: `spec/models/user_spec.rb`
- Create: `spec/models/team_spec.rb`
- Create: `spec/factories/users.rb`
- Create: `spec/factories/teams.rb`

**Step 1: Write failing model specs**

`spec/models/team_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe Team, type: :model do
  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:slug) }
  it { should validate_uniqueness_of(:slug) }
  it { should have_many(:users) }
  it { should have_many(:projects) }
end
```

`spec/models/user_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe User, type: :model do
  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:email) }
  it { should belong_to(:team) }
  it { should define_enum_for(:role).with_values(member: 0, admin: 1, owner: 2) }
end
```

**Step 2: Run tests to verify they fail**

Run: `docker compose run --rm web bundle exec rspec spec/models/`
Expected: FAIL — models don't exist yet

**Step 3: Generate Devise and models**

```bash
docker compose run --rm web bin/rails generate devise:install
docker compose run --rm web bin/rails generate model Team name:string slug:string:uniq
docker compose run --rm web bin/rails generate devise User name:string role:integer team:references
```

**Step 4: Implement Team model**

`app/models/team.rb`:
```ruby
class Team < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :projects, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, on: :create

  private

  def generate_slug
    self.slug ||= name&.parameterize
  end
end
```

**Step 5: Implement User model**

`app/models/user.rb`:
```ruby
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  belongs_to :team

  validates :name, presence: true

  enum :role, { member: 0, admin: 1, owner: 2 }, default: :member
end
```

**Step 6: Run migrations**

Run: `docker compose run --rm web bin/rails db:migrate`

**Step 7: Create factories**

`spec/factories/teams.rb`:
```ruby
FactoryBot.define do
  factory :team do
    name { Faker::Company.name }
    slug { name.parameterize }
  end
end
```

`spec/factories/users.rb`:
```ruby
FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    email { Faker::Internet.email }
    password { "password123" }
    role { :member }
    team
  end
end
```

**Step 8: Run tests to verify they pass**

Run: `docker compose run --rm web bundle exec rspec spec/models/`
Expected: All pass

**Step 9: Commit**

```bash
git add -A
git commit -m "feat: add User and Team models with Devise authentication"
```

---

### Task 4: Project Model & CRUD

**Files:**
- Create: `app/models/project.rb`
- Create: migration for projects
- Create: `app/controllers/projects_controller.rb`
- Create: `app/views/projects/` (index, show, new, edit, _form)
- Create: `spec/models/project_spec.rb`
- Create: `spec/factories/projects.rb`
- Create: `spec/requests/projects_spec.rb`
- Modify: `config/routes.rb`

**Step 1: Write failing model spec**

`spec/models/project_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe Project, type: :model do
  it { should validate_presence_of(:name) }
  it { should belong_to(:team) }
  it { should have_many(:documents) }
  it { should have_many(:blueprints) }
  it { should have_many(:phases) }
  it { should have_many(:work_orders) }
  it { should have_many(:feedback_items) }
  it { should define_enum_for(:status).with_values(active: 0, archived: 1) }
end
```

**Step 2: Run test to verify it fails**

Run: `docker compose run --rm web bundle exec rspec spec/models/project_spec.rb`
Expected: FAIL

**Step 3: Generate Project model**

```bash
docker compose run --rm web bin/rails generate model Project \
  name:string description:text status:integer team:references
```

**Step 4: Implement Project model**

`app/models/project.rb`:
```ruby
class Project < ApplicationRecord
  belongs_to :team
  has_many :documents, dependent: :destroy
  has_many :blueprints, dependent: :destroy
  has_many :phases, dependent: :destroy
  has_many :work_orders, dependent: :destroy
  has_many :feedback_items, dependent: :destroy

  validates :name, presence: true

  enum :status, { active: 0, archived: 1 }, default: :active
end
```

**Step 5: Run migration and model tests**

```bash
docker compose run --rm web bin/rails db:migrate
docker compose run --rm web bundle exec rspec spec/models/project_spec.rb
```
Expected: All pass

**Step 6: Write failing request spec**

`spec/requests/projects_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe "Projects", type: :request do
  let(:team) { create(:team) }
  let(:user) { create(:user, team: team) }

  before { sign_in user }

  describe "GET /projects" do
    it "returns http success" do
      get projects_path
      expect(response).to have_http_status(:success)
    end

    it "shows only team projects" do
      project = create(:project, team: team)
      other_project = create(:project)
      get projects_path
      expect(response.body).to include(project.name)
      expect(response.body).not_to include(other_project.name)
    end
  end

  describe "POST /projects" do
    it "creates a project for the current team" do
      expect {
        post projects_path, params: { project: { name: "New Project", description: "Test" } }
      }.to change(team.projects, :count).by(1)
      expect(response).to redirect_to(project_path(Project.last))
    end
  end
end
```

**Step 7: Run request spec to verify it fails**

Run: `docker compose run --rm web bundle exec rspec spec/requests/projects_spec.rb`
Expected: FAIL — controller doesn't exist

**Step 8: Create ProjectsController and views**

`app/controllers/projects_controller.rb`:
```ruby
class ProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: [:show, :edit, :update, :destroy]

  def index
    @projects = current_user.team.projects.order(created_at: :desc)
  end

  def show
  end

  def new
    @project = current_user.team.projects.build
  end

  def create
    @project = current_user.team.projects.build(project_params)
    if @project.save
      redirect_to @project, notice: "Project created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @project.update(project_params)
      redirect_to @project, notice: "Project updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy
    redirect_to projects_path, notice: "Project deleted."
  end

  private

  def set_project
    @project = current_user.team.projects.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name, :description)
  end
end
```

Create minimal views — `app/views/projects/index.html.erb`:
```erb
<div class="max-w-4xl mx-auto py-8">
  <div class="flex justify-between items-center mb-6">
    <h1 class="text-2xl font-bold">Projects</h1>
    <%= link_to "New Project", new_project_path, class: "btn btn-primary" %>
  </div>

  <div class="space-y-4">
    <% @projects.each do |project| %>
      <%= link_to project_path(project), class: "block p-4 border rounded hover:bg-gray-50" do %>
        <h2 class="font-semibold"><%= project.name %></h2>
        <p class="text-gray-600 text-sm"><%= project.description %></p>
      <% end %>
    <% end %>
  </div>
</div>
```

Create `app/views/projects/show.html.erb`, `new.html.erb`, `edit.html.erb`, `_form.html.erb` with similar minimal markup.

Add to `config/routes.rb`:
```ruby
resources :projects
root "projects#index"
```

**Step 9: Add factory and run tests**

`spec/factories/projects.rb`:
```ruby
FactoryBot.define do
  factory :project do
    name { Faker::App.name }
    description { Faker::Lorem.paragraph }
    status { :active }
    team
  end
end
```

Run: `docker compose run --rm web bundle exec rspec`
Expected: All pass

**Step 10: Commit**

```bash
git add -A
git commit -m "feat: add Project model with CRUD, scoped to team"
```

---

## Phase 2: Refinery Module (Requirements)

The first real module. Documents with rich text editing, versioning, comments, and the Refinery Agent sidebar.

---

### Task 5: Document Model & Migrations

**Files:**
- Create: `app/models/document.rb`
- Create: `app/models/document_version.rb`
- Create: migrations for documents and document_versions
- Create: `spec/models/document_spec.rb`
- Create: `spec/models/document_version_spec.rb`
- Create: `spec/factories/documents.rb`
- Create: `spec/factories/document_versions.rb`

**Step 1: Write failing model specs**

`spec/models/document_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe Document, type: :model do
  it { should validate_presence_of(:title) }
  it { should belong_to(:project) }
  it { should belong_to(:created_by).class_name("User") }
  it { should belong_to(:updated_by).class_name("User").optional }
  it { should have_many(:versions).class_name("DocumentVersion") }
  it { should have_many(:comments).as(:commentable) }
  it { should define_enum_for(:document_type).with_values(
    product_overview: 0,
    feature_requirement: 1,
    technical_requirement: 2
  ) }

  describe "#create_version!" do
    it "snapshots the current body and increments version" do
      document = create(:document, body: "v1 content")
      document.create_version!(create(:user))
      expect(document.versions.count).to eq(1)
      expect(document.versions.last.body_snapshot).to eq("v1 content")
      expect(document.versions.last.version_number).to eq(1)
    end
  end
end
```

**Step 2: Run to verify failure**

Run: `docker compose run --rm web bundle exec rspec spec/models/document_spec.rb`

**Step 3: Generate models**

```bash
docker compose run --rm web bin/rails generate model Document \
  project:references title:string body:text document_type:integer \
  status:string version:integer \
  created_by_id:bigint updated_by_id:bigint

docker compose run --rm web bin/rails generate model DocumentVersion \
  document:references body_snapshot:text version_number:integer \
  created_by_id:bigint diff_from_previous:text
```

**Step 4: Implement Document model**

```ruby
class Document < ApplicationRecord
  belongs_to :project
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User", optional: true
  has_many :versions, class_name: "DocumentVersion", dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy

  validates :title, presence: true

  enum :document_type, {
    product_overview: 0,
    feature_requirement: 1,
    technical_requirement: 2
  }

  after_initialize { self.version ||= 0 }

  def create_version!(user)
    new_version = version + 1
    versions.create!(
      body_snapshot: body,
      version_number: new_version,
      created_by_id: user.id
    )
    update!(version: new_version)
  end
end
```

**Step 5: Implement DocumentVersion model**

```ruby
class DocumentVersion < ApplicationRecord
  belongs_to :document
  belongs_to :created_by, class_name: "User"

  validates :version_number, presence: true
  validates :body_snapshot, presence: true
end
```

**Step 6: Run migrations and tests**

```bash
docker compose run --rm web bin/rails db:migrate
docker compose run --rm web bundle exec rspec spec/models/document_spec.rb
```
Expected: All pass

**Step 7: Create factories and commit**

```ruby
# spec/factories/documents.rb
FactoryBot.define do
  factory :document do
    title { Faker::Lorem.sentence }
    body { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    document_type { :feature_requirement }
    project
    created_by { association :user }
  end
end
```

```bash
git add -A
git commit -m "feat: add Document and DocumentVersion models with versioning"
```

---

### Task 6: Comment Model (Polymorphic)

**Files:**
- Create: `app/models/comment.rb`
- Create: migration for comments
- Create: `spec/models/comment_spec.rb`
- Create: `spec/factories/comments.rb`

**Step 1: Write failing spec**

```ruby
# spec/models/comment_spec.rb
require "rails_helper"

RSpec.describe Comment, type: :model do
  it { should validate_presence_of(:body) }
  it { should belong_to(:commentable) }
  it { should belong_to(:user) }

  it "can be attached to a document" do
    document = create(:document)
    comment = create(:comment, commentable: document)
    expect(document.comments).to include(comment)
  end
end
```

**Step 2: Run to verify failure, then generate and implement**

```bash
docker compose run --rm web bin/rails generate model Comment \
  commentable:references{polymorphic} user:references \
  body:text resolved:boolean
```

```ruby
class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true
  belongs_to :user

  validates :body, presence: true

  after_initialize { self.resolved ||= false }
end
```

**Step 3: Migrate, test, commit**

```bash
docker compose run --rm web bin/rails db:migrate
docker compose run --rm web bundle exec rspec spec/models/comment_spec.rb
git add -A
git commit -m "feat: add polymorphic Comment model"
```

---

### Task 7: Documents Controller & Views with Tiptap Editor

**Files:**
- Create: `app/controllers/documents_controller.rb`
- Create: `app/views/documents/` (show, new, edit, _form, _sidebar)
- Create: `app/javascript/controllers/tiptap_controller.js`
- Create: `spec/requests/documents_spec.rb`
- Modify: `config/routes.rb`
- Modify: `package.json` (add tiptap deps)

**Step 1: Install Tiptap dependencies**

```bash
docker compose run --rm web yarn add @tiptap/core @tiptap/starter-kit @tiptap/extension-collaboration @tiptap/extension-placeholder @tiptap/pm
```

**Step 2: Write failing request spec**

```ruby
# spec/requests/documents_spec.rb
require "rails_helper"

RSpec.describe "Documents", type: :request do
  let(:team) { create(:team) }
  let(:user) { create(:user, team: team) }
  let(:project) { create(:project, team: team) }

  before { sign_in user }

  describe "GET /projects/:project_id/documents/:id" do
    it "returns http success" do
      document = create(:document, project: project, created_by: user)
      get project_document_path(project, document)
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /projects/:project_id/documents" do
    it "creates a document" do
      expect {
        post project_documents_path(project), params: {
          document: { title: "Feature Spec", body: "Content", document_type: "feature_requirement" }
        }
      }.to change(project.documents, :count).by(1)
    end
  end
end
```

**Step 3: Run to verify failure**

Run: `docker compose run --rm web bundle exec rspec spec/requests/documents_spec.rb`

**Step 4: Add routes**

```ruby
# config/routes.rb
resources :projects do
  resources :documents
end
```

**Step 5: Create DocumentsController**

```ruby
class DocumentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project
  before_action :set_document, only: [:show, :edit, :update, :destroy]

  def index
    @documents = @project.documents.order(created_at: :desc)
  end

  def show
  end

  def new
    @document = @project.documents.build
  end

  def create
    @document = @project.documents.build(document_params)
    @document.created_by = current_user
    if @document.save
      redirect_to project_document_path(@project, @document)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @document.updated_by = current_user
    if @document.update(document_params)
      @document.create_version!(current_user)
      redirect_to project_document_path(@project, @document)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @document.destroy
    redirect_to project_documents_path(@project)
  end

  private

  def set_project
    @project = current_user.team.projects.find(params[:project_id])
  end

  def set_document
    @document = @project.documents.find(params[:id])
  end

  def document_params
    params.require(:document).permit(:title, :body, :document_type)
  end
end
```

**Step 6: Create Tiptap Stimulus controller**

`app/javascript/controllers/tiptap_controller.js`:
```javascript
import { Controller } from "@hotwired/stimulus"
import { Editor } from "@tiptap/core"
import StarterKit from "@tiptap/starter-kit"
import Placeholder from "@tiptap/extension-placeholder"

export default class extends Controller {
  static targets = ["editor", "input"]
  static values = { content: String }

  connect() {
    this.editor = new Editor({
      element: this.editorTarget,
      extensions: [
        StarterKit,
        Placeholder.configure({
          placeholder: "Start writing..."
        })
      ],
      content: this.contentValue || "",
      onUpdate: ({ editor }) => {
        this.inputTarget.value = editor.getHTML()
      }
    })
  }

  disconnect() {
    this.editor.destroy()
  }
}
```

**Step 7: Create document show view with editor and agent sidebar layout**

`app/views/documents/show.html.erb`:
```erb
<div class="flex h-screen">
  <!-- Main editor area -->
  <div class="flex-1 p-8 overflow-y-auto">
    <div class="max-w-3xl mx-auto">
      <div class="mb-4">
        <span class="text-sm text-gray-500 uppercase"><%= @document.document_type.humanize %></span>
        <h1 class="text-3xl font-bold"><%= @document.title %></h1>
        <p class="text-sm text-gray-500">
          v<%= @document.version %> &middot; Updated by <%= @document.updated_by&.name || @document.created_by.name %>
        </p>
      </div>

      <div data-controller="tiptap"
           data-tiptap-content-value="<%= @document.body %>">
        <div data-tiptap-target="editor" class="prose max-w-none min-h-[400px] border rounded p-4"></div>
        <input type="hidden" data-tiptap-target="input" name="document[body]">
      </div>
    </div>
  </div>

  <!-- Agent sidebar (placeholder for Task 12) -->
  <div class="w-96 border-l bg-gray-50 p-4 overflow-y-auto">
    <h2 class="font-semibold mb-4">Refinery Agent</h2>
    <p class="text-sm text-gray-500">Agent chat coming soon...</p>
  </div>
</div>
```

**Step 8: Run tests and commit**

```bash
docker compose run --rm web bundle exec rspec
git add -A
git commit -m "feat: add Documents controller with Tiptap rich text editor"
```

---

### Task 8: Auto-Generate Placeholder Docs on Project Creation

**Files:**
- Modify: `app/models/project.rb`
- Create: `spec/models/project_spec.rb` (add to existing)

**Step 1: Write failing test**

Add to `spec/models/project_spec.rb`:
```ruby
describe "after creation" do
  it "generates placeholder Product Overview and Technical Requirements documents" do
    user = create(:user)
    project = create(:project, team: user.team)
    # Need to pass a user context - use a callback or service
    Project.seed_documents(project, user)
    expect(project.documents.product_overview.count).to eq(1)
    expect(project.documents.technical_requirement.count).to eq(1)
  end
end
```

**Step 2: Implement Project.seed_documents**

Add to `app/models/project.rb`:
```ruby
def self.seed_documents(project, user)
  project.documents.create!(
    title: "Product Overview",
    body: "<h2>Business Problem</h2><p></p><h2>Target Users</h2><p></p><h2>Success Criteria</h2><p></p>",
    document_type: :product_overview,
    created_by: user
  )
  project.documents.create!(
    title: "Technical Requirements",
    body: "<h2>Authentication & Authorization</h2><p></p><h2>Performance</h2><p></p><h2>Security</h2><p></p>",
    document_type: :technical_requirement,
    created_by: user
  )
end
```

Call from `ProjectsController#create` after save.

**Step 3: Run tests and commit**

```bash
docker compose run --rm web bundle exec rspec
git add -A
git commit -m "feat: auto-generate placeholder docs on project creation"
```

---

## Phase 3: Foundry Module (Architecture)

---

### Task 9: Blueprint Model & Controller

**Files:**
- Create: `app/models/blueprint.rb`
- Create: `app/models/blueprint_version.rb`
- Create: migrations
- Create: `app/controllers/blueprints_controller.rb`
- Create: `app/views/blueprints/`
- Create: `app/javascript/controllers/mermaid_controller.js`
- Create: specs and factories

Follow the exact same pattern as Tasks 5-7 but for Blueprints. Key differences:

- `blueprint_type` enum: `foundation: 0, system_diagram: 1, feature_blueprint: 2`
- System diagram view includes a Mermaid.js renderer:

```javascript
// app/javascript/controllers/mermaid_controller.js
import { Controller } from "@hotwired/stimulus"
import mermaid from "mermaid"

export default class extends Controller {
  static targets = ["source", "preview"]

  connect() {
    mermaid.initialize({ startOnLoad: false, theme: "default" })
    this.render()
  }

  render() {
    const code = this.sourceTarget.textContent
    mermaid.render("mermaid-preview", code).then(({ svg }) => {
      this.previewTarget.innerHTML = svg
    })
  }
}
```

- Feature blueprints have an optional `document_id` FK linking to the originating Feature Requirement doc
- Routes nest under projects: `resources :projects { resources :blueprints }`

**Commit message:** `feat: add Blueprint model with Mermaid diagram support`

---

## Phase 4: Planner Module (Jira Replacement)

---

### Task 10: Phase & WorkOrder Models

**Files:**
- Create: `app/models/phase.rb`
- Create: `app/models/work_order.rb`
- Create: migrations
- Create: specs and factories

**Step 1: Write failing specs**

`spec/models/work_order_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe WorkOrder, type: :model do
  it { should validate_presence_of(:title) }
  it { should belong_to(:project) }
  it { should belong_to(:phase).optional }
  it { should belong_to(:assignee).class_name("User").optional }
  it { should have_many(:comments).as(:commentable) }
  it { should define_enum_for(:status).with_values(
    backlog: 0, todo: 1, in_progress: 2, review: 3, done: 4
  ) }
  it { should define_enum_for(:priority).with_values(
    low: 0, medium: 1, high: 2, critical: 3
  ) }
end
```

**Step 2: Generate, implement, test, commit**

Same TDD cycle. Work order has: title, description (text), acceptance_criteria (text), implementation_plan (text), status (integer enum), priority (integer enum), position (integer for ordering), project_id, phase_id, assignee_id.

Phase has: name, position, project_id.

```bash
git commit -m "feat: add Phase and WorkOrder models"
```

---

### Task 11: Kanban Board with Turbo

**Files:**
- Create: `app/controllers/work_orders_controller.rb`
- Create: `app/views/work_orders/` (index with kanban, show, new, edit)
- Create: `app/javascript/controllers/kanban_controller.js`
- Create: `spec/requests/work_orders_spec.rb`

**Step 1: Install Sortable.js**

```bash
docker compose run --rm web yarn add sortablejs
```

**Step 2: Write failing request spec for status update**

```ruby
describe "PATCH /projects/:project_id/work_orders/:id" do
  it "updates status and broadcasts via Turbo" do
    work_order = create(:work_order, project: project, status: :todo)
    patch project_work_order_path(project, work_order),
      params: { work_order: { status: "in_progress" } },
      as: :turbo_stream
    expect(work_order.reload.status).to eq("in_progress")
  end
end
```

**Step 3: Create Kanban Stimulus controller**

```javascript
// app/javascript/controllers/kanban_controller.js
import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["column"]
  static values = { url: String }

  connect() {
    this.columnTargets.forEach(column => {
      Sortable.create(column, {
        group: "kanban",
        animation: 150,
        onEnd: (event) => {
          const workOrderId = event.item.dataset.workOrderId
          const newStatus = event.to.dataset.status
          const position = event.newIndex

          fetch(this.urlValue.replace(":id", workOrderId), {
            method: "PATCH",
            headers: {
              "Content-Type": "application/json",
              "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
            },
            body: JSON.stringify({
              work_order: { status: newStatus, position: position }
            })
          })
        }
      })
    })
  }
}
```

**Step 4: Create kanban view**

`app/views/work_orders/index.html.erb`:
```erb
<div class="p-6">
  <div class="flex justify-between items-center mb-6">
    <h1 class="text-2xl font-bold">Work Orders</h1>
    <%= link_to "New Work Order", new_project_work_order_path(@project), class: "btn" %>
  </div>

  <div data-controller="kanban"
       data-kanban-url-value="<%= project_work_order_path(@project, ':id') %>"
       class="flex gap-4 overflow-x-auto">
    <% %w[backlog todo in_progress review done].each do |status| %>
      <div class="min-w-[280px] bg-gray-100 rounded p-3">
        <h3 class="font-semibold mb-3 text-sm uppercase text-gray-600"><%= status.humanize %></h3>
        <div data-kanban-target="column" data-status="<%= status %>" class="space-y-2 min-h-[100px]">
          <% @work_orders.select { |wo| wo.status == status }.sort_by(&:position).each do |wo| %>
            <div data-work-order-id="<%= wo.id %>"
                 class="bg-white rounded p-3 shadow-sm border cursor-move">
              <p class="font-medium text-sm"><%= wo.title %></p>
              <div class="flex items-center gap-2 mt-2">
                <span class="text-xs px-2 py-0.5 rounded bg-gray-200"><%= wo.priority %></span>
                <% if wo.assignee %>
                  <span class="text-xs text-gray-500"><%= wo.assignee.name %></span>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
  </div>
</div>
```

**Step 5: Add Turbo Stream broadcast to WorkOrder model**

```ruby
# app/models/work_order.rb
after_update_commit -> {
  broadcast_replace_to(
    "project_#{project_id}_work_orders",
    target: "work_order_#{id}",
    partial: "work_orders/work_order_card"
  )
}
```

**Step 6: Run tests and commit**

```bash
docker compose run --rm web bundle exec rspec
git add -A
git commit -m "feat: add kanban board with drag-and-drop via Sortable.js + Turbo"
```

---

## Phase 5: Knowledge Graph (Neo4j Integration)

---

### Task 12: GraphSync Concern & Node Management

**Files:**
- Create: `app/models/concerns/graph_sync.rb`
- Create: `app/services/graph_service.rb`
- Create: `spec/services/graph_service_spec.rb`
- Create: `spec/models/concerns/graph_sync_spec.rb`

**Step 1: Write failing spec for GraphService**

```ruby
# spec/services/graph_service_spec.rb
require "rails_helper"

RSpec.describe GraphService do
  describe ".create_node" do
    it "creates a node in Neo4j with the correct label and properties" do
      result = GraphService.create_node("Document", { postgres_id: 1, title: "Test" })
      expect(result).to be_truthy
    end
  end

  describe ".create_edge" do
    it "creates a relationship between two nodes" do
      GraphService.create_node("Document", { postgres_id: 1 })
      GraphService.create_node("Blueprint", { postgres_id: 2 })
      result = GraphService.create_edge(
        from: { label: "Document", postgres_id: 1 },
        to: { label: "Blueprint", postgres_id: 2 },
        type: "DEFINES_FEATURE"
      )
      expect(result).to be_truthy
    end
  end

  describe ".neighbors" do
    it "returns connected nodes" do
      GraphService.create_node("Document", { postgres_id: 1 })
      GraphService.create_node("Blueprint", { postgres_id: 2 })
      GraphService.create_edge(
        from: { label: "Document", postgres_id: 1 },
        to: { label: "Blueprint", postgres_id: 2 },
        type: "DEFINES_FEATURE"
      )
      neighbors = GraphService.neighbors("Document", 1)
      expect(neighbors.length).to eq(1)
      expect(neighbors.first[:label]).to eq("Blueprint")
    end
  end
end
```

**Step 2: Implement GraphService**

```ruby
# app/services/graph_service.rb
class GraphService
  class << self
    def create_node(label, properties)
      execute(
        "MERGE (n:#{label} {postgres_id: $id}) SET n += $props",
        id: properties[:postgres_id],
        props: properties.except(:postgres_id)
      )
    end

    def delete_node(label, postgres_id)
      execute(
        "MATCH (n:#{label} {postgres_id: $id}) DETACH DELETE n",
        id: postgres_id
      )
    end

    def create_edge(from:, to:, type:, properties: {})
      execute(
        "MATCH (a:#{from[:label]} {postgres_id: $from_id}) " \
        "MATCH (b:#{to[:label]} {postgres_id: $to_id}) " \
        "MERGE (a)-[r:#{type}]->(b) SET r += $props",
        from_id: from[:postgres_id],
        to_id: to[:postgres_id],
        props: properties
      )
    end

    def delete_edge(from:, to:, type:)
      execute(
        "MATCH (a:#{from[:label]} {postgres_id: $from_id})" \
        "-[r:#{type}]->" \
        "(b:#{to[:label]} {postgres_id: $to_id}) DELETE r",
        from_id: from[:postgres_id],
        to_id: to[:postgres_id]
      )
    end

    def neighbors(label, postgres_id, direction: :both)
      arrow = case direction
              when :outgoing then "-[r]->"
              when :incoming then "<-[r]-"
              else "-[r]-"
              end

      results = execute(
        "MATCH (n:#{label} {postgres_id: $id})#{arrow}(m) " \
        "RETURN labels(m)[0] AS label, m.postgres_id AS postgres_id, type(r) AS relationship",
        id: postgres_id
      )
      results.map { |r| { label: r[:label], postgres_id: r[:postgres_id], relationship: r[:relationship] } }
    end

    def impact_analysis(label, postgres_id, depth: 3)
      execute(
        "MATCH path = (n:#{label} {postgres_id: $id})-[*1..#{depth}]->(m) " \
        "RETURN [node in nodes(path) | {label: labels(node)[0], id: node.postgres_id}] AS chain",
        id: postgres_id
      )
    end

    private

    def execute(query, **params)
      session = NEO4J_DRIVER.session
      result = session.run(query, **params)
      result.to_a.map { |record| record.to_h }
    ensure
      session&.close
    end
  end
end
```

**Step 3: Create GraphSync concern**

```ruby
# app/models/concerns/graph_sync.rb
module GraphSync
  extend ActiveSupport::Concern

  included do
    after_commit :sync_to_graph, on: [:create, :update]
    after_commit :remove_from_graph, on: :destroy
  end

  def graph_label
    self.class.name
  end

  def graph_properties
    { postgres_id: id, title: try(:title) || try(:name) }
  end

  private

  def sync_to_graph
    GraphService.create_node(graph_label, graph_properties)
  end

  def remove_from_graph
    GraphService.delete_node(graph_label, id)
  end
end
```

**Step 4: Include in models**

Add `include GraphSync` to: `Document`, `Blueprint`, `WorkOrder`, `FeedbackItem`, `System`

**Step 5: Run tests and commit**

```bash
docker compose run --rm web bundle exec rspec
git add -A
git commit -m "feat: add GraphService and GraphSync concern for Neo4j integration"
```

---

### Task 13: Drift Detection Background Job

**Files:**
- Create: `app/jobs/drift_detection_job.rb`
- Create: `spec/jobs/drift_detection_job_spec.rb`
- Create: `app/models/drift_alert.rb`
- Create: migration for drift_alerts

**Step 1: Write failing spec**

```ruby
# spec/jobs/drift_detection_job_spec.rb
require "rails_helper"

RSpec.describe DriftDetectionJob do
  it "creates a drift alert when a document is newer than its linked blueprint" do
    document = create(:document, updated_at: 1.hour.ago)
    blueprint = create(:blueprint, updated_at: 2.days.ago)
    GraphService.create_node("Document", { postgres_id: document.id })
    GraphService.create_node("Blueprint", { postgres_id: blueprint.id })
    GraphService.create_edge(
      from: { label: "Document", postgres_id: document.id },
      to: { label: "Blueprint", postgres_id: blueprint.id },
      type: "DEFINES_FEATURE"
    )

    expect { DriftDetectionJob.perform_now }.to change(DriftAlert, :count).by(1)
    alert = DriftAlert.last
    expect(alert.source_type).to eq("Document")
    expect(alert.message).to include("updated since")
  end
end
```

**Step 2: Implement DriftAlert model and job**

```ruby
# DriftAlert: id, project_id, source_type, source_id, target_type, target_id, message, status (open/resolved)

class DriftDetectionJob < ApplicationJob
  queue_as :default

  def perform
    check_document_blueprint_drift
    check_blueprint_work_order_drift
  end

  private

  def check_document_blueprint_drift
    edges = GraphService.execute(
      "MATCH (d:Document)-[:DEFINES_FEATURE]->(b:Blueprint) " \
      "RETURN d.postgres_id AS doc_id, b.postgres_id AS bp_id"
    )

    edges.each do |edge|
      doc = Document.find_by(id: edge[:doc_id])
      bp = Blueprint.find_by(id: edge[:bp_id])
      next unless doc && bp
      next unless doc.updated_at > bp.updated_at

      DriftAlert.find_or_create_by!(
        source_type: "Document", source_id: doc.id,
        target_type: "Blueprint", target_id: bp.id,
        status: :open
      ) do |alert|
        alert.project = doc.project
        alert.message = "#{doc.title} was updated since #{bp.title} was last reviewed"
      end
    end
  end

  def check_blueprint_work_order_drift
    # Same pattern for Blueprint -> WorkOrder edges
  end
end
```

**Step 3: Schedule via Solid Queue**

Add to `config/recurring.yml`:
```yaml
drift_detection:
  class: DriftDetectionJob
  schedule: every 30 minutes
```

**Step 4: Run tests and commit**

```bash
docker compose run --rm web bundle exec rspec
git add -A
git commit -m "feat: add drift detection job with DriftAlert model"
```

---

## Phase 6: AI Agent Layer

---

### Task 14: AgentService & Context Builder

**Files:**
- Create: `app/services/agent_service.rb`
- Create: `app/services/context_builder.rb`
- Create: `app/models/agent_conversation.rb`
- Create: `app/models/agent_message.rb`
- Create: migrations
- Create: `spec/services/agent_service_spec.rb`
- Create: `spec/services/context_builder_spec.rb`

**Step 1: Write failing spec for ContextBuilder**

```ruby
# spec/services/context_builder_spec.rb
require "rails_helper"

RSpec.describe ContextBuilder do
  let(:project) { create(:project) }
  let(:document) { create(:document, project: project) }

  it "builds context with the current document" do
    context = ContextBuilder.new(project)
      .add_document(document)
      .build

    expect(context).to include(document.title)
    expect(context).to include(document.body)
  end

  it "respects token limits by truncating lower-priority sections" do
    context = ContextBuilder.new(project, max_tokens: 100)
      .add_document(document)
      .build

    expect(context.length).to be <= 400  # rough char estimate
  end
end
```

**Step 2: Implement ContextBuilder**

```ruby
class ContextBuilder
  CHARS_PER_TOKEN = 4

  def initialize(project, max_tokens: 8000)
    @project = project
    @max_chars = max_tokens * CHARS_PER_TOKEN
    @sections = []
  end

  def add_document(document)
    @sections << { priority: 1, label: "Current Document", content: format_document(document) }
    self
  end

  def add_graph_neighbors(record)
    neighbors = GraphService.neighbors(record.class.name, record.id)
    neighbor_records = neighbors.map { |n| n[:label].constantize.find_by(id: n[:postgres_id]) }.compact
    neighbor_records.each do |rec|
      @sections << { priority: 2, label: "Linked: #{rec.class.name}", content: format_record(rec) }
    end
    self
  end

  def add_system_dependencies(systems)
    Array(systems).each do |system|
      deps = GraphService.neighbors("System", system.id)
      @sections << { priority: 3, label: "System: #{system.name}", content: format_dependencies(system, deps) }
    end
    self
  end

  def add_codebase_snippets(files)
    Array(files).each do |file|
      @sections << { priority: 4, label: "Code: #{file.path}", content: file.content }
    end
    self
  end

  def add_conversation_history(conversation)
    return self unless conversation
    messages = conversation.messages.order(:created_at).last(20)
    content = messages.map { |m| "#{m.role}: #{m.content}" }.join("\n")
    @sections << { priority: 5, label: "Conversation History", content: content }
    self
  end

  def build
    sorted = @sections.sort_by { |s| s[:priority] }
    result = []
    total = 0

    sorted.each do |section|
      section_text = "## #{section[:label]}\n\n#{section[:content]}\n\n"
      break if total + section_text.length > @max_chars
      result << section_text
      total += section_text.length
    end

    result.join
  end

  private

  def format_document(doc)
    "**#{doc.title}** (#{doc.try(:document_type) || doc.try(:blueprint_type)})\n\n#{doc.body}"
  end

  def format_record(rec)
    "**#{rec.try(:title) || rec.try(:name)}**\n#{rec.try(:body) || rec.try(:description)}"
  end

  def format_dependencies(system, deps)
    lines = deps.map { |d| "- #{d[:relationship]} -> #{d[:label]} (ID: #{d[:postgres_id]})" }
    "#{system.name} (#{system.system_type})\n#{lines.join("\n")}"
  end
end
```

**Step 3: Write failing spec for AgentService**

```ruby
# spec/services/agent_service_spec.rb
require "rails_helper"

RSpec.describe AgentService do
  let(:user) { create(:user) }
  let(:document) { create(:document) }

  before do
    stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
      .to_return(status: 200, body: {
        choices: [{ message: { content: "Here is my analysis..." } }]
      }.to_json)
  end

  it "sends context to OpenRouter and persists the conversation" do
    service = AgentService.new(
      user: user,
      conversable: document,
      system_prompt: "You are the Refinery Agent."
    )
    response = service.chat("Review this document for gaps")

    expect(response).to include("analysis")
    expect(document.agent_conversations.count).to eq(1)
    expect(document.agent_conversations.first.messages.count).to eq(3) # system + user + assistant
  end
end
```

**Step 4: Implement AgentService**

```ruby
class AgentService
  def initialize(user:, conversable:, system_prompt:, model: "anthropic/claude-sonnet-4-5-20250929")
    @user = user
    @conversable = conversable
    @system_prompt = system_prompt
    @model = model
    @conversation = find_or_create_conversation
  end

  def chat(message)
    @conversation.messages.create!(role: "user", content: message)

    messages = build_messages
    response = OPENROUTER_CLIENT.chat(
      parameters: {
        model: @model,
        messages: messages
      }
    )

    assistant_content = response.dig("choices", 0, "message", "content")
    @conversation.messages.create!(role: "assistant", content: assistant_content)
    assistant_content
  end

  private

  def find_or_create_conversation
    conv = AgentConversation.find_or_create_by!(
      conversable: @conversable,
      user: @user
    ) do |c|
      c.model_provider = "openrouter"
      c.model_name = @model
    end

    if conv.messages.empty?
      conv.messages.create!(role: "system", content: @system_prompt)
    end

    conv
  end

  def build_messages
    @conversation.messages.order(:created_at).map do |msg|
      { role: msg.role, content: msg.content }
    end
  end
end
```

**Step 5: Create migrations, models, run tests, commit**

```bash
docker compose run --rm web bin/rails generate model AgentConversation \
  conversable:references{polymorphic} user:references \
  model_provider:string model_name:string

docker compose run --rm web bin/rails generate model AgentMessage \
  agent_conversation:references role:string content:text

docker compose run --rm web bin/rails db:migrate
docker compose run --rm web bundle exec rspec
git add -A
git commit -m "feat: add AgentService with ContextBuilder and OpenRouter integration"
```

---

### Task 15: Agent Chat Sidebar with Streaming

**Files:**
- Create: `app/controllers/agent_chats_controller.rb`
- Create: `app/channels/agent_chat_channel.rb`
- Create: `app/views/agent_chats/_sidebar.html.erb`
- Create: `app/javascript/controllers/agent_chat_controller.js`
- Create: `app/jobs/agent_chat_job.rb`
- Modify: `config/routes.rb`

**Step 1: Create the agent chat channel**

```ruby
# app/channels/agent_chat_channel.rb
class AgentChatChannel < ApplicationCable::Channel
  def subscribed
    stream_from "agent_chat_#{params[:conversable_type]}_#{params[:conversable_id]}"
  end
end
```

**Step 2: Create the background job for streaming**

```ruby
# app/jobs/agent_chat_job.rb
class AgentChatJob < ApplicationJob
  queue_as :default

  def perform(conversation_id:, message:, system_prompt:)
    conversation = AgentConversation.find(conversation_id)
    conversation.messages.create!(role: "user", content: message)

    messages = conversation.messages.order(:created_at).map { |m| { role: m.role, content: m.content } }

    # Stream response
    full_response = ""
    OPENROUTER_CLIENT.chat(
      parameters: {
        model: conversation.model_name,
        messages: messages,
        stream: proc { |chunk|
          delta = chunk.dig("choices", 0, "delta", "content")
          if delta
            full_response += delta
            ActionCable.server.broadcast(
              "agent_chat_#{conversation.conversable_type}_#{conversation.conversable_id}",
              { type: "delta", content: delta }
            )
          end
        }
      }
    )

    conversation.messages.create!(role: "assistant", content: full_response)
    ActionCable.server.broadcast(
      "agent_chat_#{conversation.conversable_type}_#{conversation.conversable_id}",
      { type: "complete" }
    )
  end
end
```

**Step 3: Create Stimulus controller for chat UI**

```javascript
// app/javascript/controllers/agent_chat_controller.js
import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["messages", "input", "response"]
  static values = { conversableType: String, conversableId: Number, url: String }

  connect() {
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      { channel: "AgentChatChannel", conversable_type: this.conversableTypeValue, conversable_id: this.conversableIdValue },
      {
        received: (data) => {
          if (data.type === "delta") {
            this.responseTarget.textContent += data.content
          } else if (data.type === "complete") {
            // Move response to messages list
            const msg = document.createElement("div")
            msg.className = "p-3 bg-blue-50 rounded text-sm mb-2"
            msg.textContent = this.responseTarget.textContent
            this.messagesTarget.appendChild(msg)
            this.responseTarget.textContent = ""
          }
        }
      }
    )
  }

  send() {
    const message = this.inputTarget.value
    if (!message.trim()) return

    // Show user message
    const userMsg = document.createElement("div")
    userMsg.className = "p-3 bg-gray-100 rounded text-sm mb-2"
    userMsg.textContent = message
    this.messagesTarget.appendChild(userMsg)

    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
      },
      body: JSON.stringify({ message: message })
    })

    this.inputTarget.value = ""
  }

  disconnect() {
    this.subscription?.unsubscribe()
    this.consumer?.disconnect()
  }
}
```

**Step 4: Create controller endpoint**

```ruby
# app/controllers/agent_chats_controller.rb
class AgentChatsController < ApplicationController
  before_action :authenticate_user!

  def create
    conversable = params[:conversable_type].constantize.find(params[:conversable_id])
    conversation = AgentConversation.find_or_create_by!(
      conversable: conversable, user: current_user
    ) do |c|
      c.model_provider = "openrouter"
      c.model_name = "anthropic/claude-sonnet-4-5-20250929"
    end

    system_prompt = agent_system_prompt(conversable)
    AgentChatJob.perform_later(
      conversation_id: conversation.id,
      message: params[:message],
      system_prompt: system_prompt
    )

    head :accepted
  end

  private

  def agent_system_prompt(conversable)
    case conversable
    when Document then RefineryAgentPrompt.call(conversable)
    when Blueprint then FoundryAgentPrompt.call(conversable)
    when WorkOrder then PlannerAgentPrompt.call(conversable)
    else "You are a helpful assistant."
    end
  end
end
```

**Step 5: Add route and commit**

```ruby
post "/agent_chats", to: "agent_chats#create"
```

```bash
docker compose run --rm web bundle exec rspec
git add -A
git commit -m "feat: add agent chat sidebar with streaming via Action Cable"
```

---

## Phase 7: System Registry & Dependencies

---

### Task 16: System & SystemDependency Models

**Files:**
- Create: `app/models/system.rb` (note: avoid collision with Ruby's System — name it `ServiceSystem`)
- Create: `app/models/system_dependency.rb`
- Create: migrations, specs, factories

Follow TDD cycle. Key points:
- Name the model `ServiceSystem` to avoid Ruby namespace collision
- Table name: `service_systems`
- `system_type` enum: `service: 0, library: 1, database: 2, queue: 3, external_api: 4`
- `dependency_type` enum: `http_api: 0, rabbitmq: 1, grpc: 2, database_shared: 3, event_bus: 4, sdk: 5`
- Include `GraphSync` concern
- Neo4j edges created via after_commit on SystemDependency

**Commit:** `feat: add ServiceSystem and SystemDependency models with graph sync`

---

### Task 17: System Map Visualization

**Files:**
- Create: `app/controllers/systems_controller.rb`
- Create: `app/views/systems/index.html.erb` (map view)
- Create: `app/javascript/controllers/system_map_controller.js`
- Create: `spec/requests/systems_spec.rb`

Use D3.js force-directed graph to render the system map. Each node is a service, edges show dependency type (HTTP, RabbitMQ, etc.) with labels.

```bash
docker compose run --rm web yarn add d3
```

The controller provides a JSON endpoint with nodes and edges for D3 to consume:

```ruby
def index
  @systems = current_user.team.service_systems
  respond_to do |format|
    format.html
    format.json {
      render json: {
        nodes: @systems.map { |s| { id: s.id, name: s.name, type: s.system_type } },
        edges: SystemDependency.where(source_system: @systems).map { |d|
          { source: d.source_system_id, target: d.target_system_id, type: d.dependency_type, metadata: d.metadata }
        }
      }
    }
  end
end
```

**Commit:** `feat: add system map visualization with D3.js force graph`

---

## Phase 8: Validator Module

---

### Task 18: FeedbackItem Model & API Endpoint

**Files:**
- Create: `app/models/feedback_item.rb`
- Create: `app/models/app_key.rb`
- Create: migrations
- Create: `app/controllers/api/v1/feedback_controller.rb`
- Create: specs

**Step 1: Write specs for API endpoint**

```ruby
# spec/requests/api/v1/feedback_spec.rb
require "rails_helper"

RSpec.describe "Feedback API", type: :request do
  let(:project) { create(:project) }
  let(:app_key) { create(:app_key, project: project) }

  describe "POST /api/v1/feedback" do
    it "creates a feedback item with valid app key" do
      post "/api/v1/feedback", params: {
        title: "Checkout broken",
        body: "500 error on submit",
        technical_context: { browser: "Chrome 120", url: "/checkout" }
      }, headers: { "Authorization" => "Bearer #{app_key.token}" }

      expect(response).to have_http_status(:created)
      expect(FeedbackItem.last.title).to eq("Checkout broken")
    end

    it "auto-categorizes via AI after creation" do
      stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
        .to_return(body: { choices: [{ message: { content: '{"category": "bug", "score": 8}' } }] }.to_json)

      post "/api/v1/feedback", params: {
        title: "Button doesn't work",
        body: "Click does nothing"
      }, headers: { "Authorization" => "Bearer #{app_key.token}" }

      expect(FeedbackItem.last.category).to eq("bug")
      expect(FeedbackItem.last.score).to eq(8)
    end
  end
end
```

**Step 2: Implement models, controller, auto-triage job**

AppKey model: `id, project_id, token (sf-int-xxxxx format), name, active`
FeedbackItem: as defined in design doc, include `GraphSync`

Auto-triage: `FeedbackTriageJob` calls OpenRouter to classify and score, runs after_create.

**Commit:** `feat: add Validator API endpoint with auto-triage`

---

### Task 19: Validator Inbox UI

**Files:**
- Create: `app/controllers/feedback_items_controller.rb`
- Create: `app/views/feedback_items/index.html.erb` (inbox)
- Create: `app/views/feedback_items/show.html.erb`
- Create: `spec/requests/feedback_items_spec.rb`

Inbox: filterable table with columns for title, category, score, status, created_at. Filter by category, status. "Create Work Order" button on each item that pre-fills a new work order form and creates the Neo4j edge.

**Commit:** `feat: add Validator inbox with filtering and work order creation`

---

## Phase 9: Real-Time Collaboration

---

### Task 20: Action Cable Channels & Presence

**Files:**
- Create: `app/channels/project_channel.rb`
- Create: `app/channels/document_channel.rb`
- Create: `app/channels/notification_channel.rb`
- Create: `app/javascript/controllers/presence_controller.js`
- Create: `app/models/notification.rb`
- Create: migration for notifications

**Key implementations:**

ProjectChannel: broadcasts work order changes, new documents, new comments
DocumentChannel: broadcasts editing changes and cursor positions
NotificationChannel: per-user stream for mentions, assignments, drift alerts

Notification model: `id, user_id, notifiable_type, notifiable_id, message, read, created_at`

Presence tracking: on DocumentChannel subscribe/unsubscribe, broadcast who is viewing.

**Commit:** `feat: add real-time channels for collaboration and presence tracking`

---

### Task 21: Notification Center UI

**Files:**
- Create: `app/views/shared/_notification_bell.html.erb`
- Create: `app/javascript/controllers/notifications_controller.js`
- Create: `app/controllers/notifications_controller.rb`
- Modify: `app/views/layouts/application.html.erb`

Bell icon with unread count badge. Dropdown shows recent notifications. Click marks as read. Real-time counter updates via NotificationChannel.

**Commit:** `feat: add notification center with real-time updates`

---

## Phase 10: Codebase Indexing

---

### Task 22: Repository Model & Indexing Pipeline

**Files:**
- Create: `app/models/repository.rb`
- Create: `app/models/codebase_file.rb`
- Create: `app/models/codebase_chunk.rb`
- Create: `app/models/extracted_artifact.rb`
- Create: migrations
- Create: `app/jobs/codebase_index_job.rb`
- Create: `app/services/code_parser.rb`
- Create: specs

The indexing job:
1. Clones/pulls the repo via `git` shell commands
2. Walks the file tree, creates/updates CodebaseFile records
3. Parses files with CodeParser (language-aware extraction)
4. Chunks code and generates embeddings via OpenRouter
5. Stores chunks with pgvector embeddings
6. Creates ExtractedArtifact records
7. Syncs to Neo4j via GraphSync

CodeParser extracts:
- Ruby/Rails: routes (`config/routes.rb`), controllers, models, service objects
- JavaScript/TypeScript: API client calls, event emitters
- Config: OpenAPI specs, protobuf definitions, docker-compose services
- Queue declarations: Bunny/Sneakers publishers and consumers

**Commit:** `feat: add codebase indexing pipeline with pgvector embeddings`

---

### Task 23: Semantic Code Search

**Files:**
- Create: `app/services/code_search_service.rb`
- Create: `spec/services/code_search_service_spec.rb`

Uses pgvector's nearest-neighbor search to find relevant code chunks given a natural language query. Integrated into ContextBuilder for agent context assembly.

```ruby
class CodeSearchService
  def self.search(project, query, limit: 10)
    embedding = generate_embedding(query)
    CodebaseChunk
      .joins(codebase_file: :repository)
      .where(repositories: { system_id: project.team.service_systems.select(:id) })
      .nearest_neighbors(:embedding, embedding, distance: "cosine")
      .limit(limit)
  end

  private

  def self.generate_embedding(text)
    response = OPENROUTER_CLIENT.embeddings(
      parameters: { model: "openai/text-embedding-3-small", input: text }
    )
    response.dig("data", 0, "embedding")
  end
end
```

**Commit:** `feat: add semantic code search with pgvector`

---

## Phase 11: MCP Server

---

### Task 24: MCP Server Implementation

**Files:**
- Create: `app/mcp/constitution_mcp_server.rb`
- Create: `app/mcp/tools/` (one file per tool)
- Create: `bin/mcp`
- Create: `spec/mcp/` specs

Implement an MCP server using the `mcp` Ruby gem (or build a minimal JSON-RPC server) that exposes:

**Tools:**
- `constitution.list_work_orders` — query by project, assignee, status
- `constitution.get_work_order` — full detail with implementation plan
- `constitution.update_work_order_status` — change status
- `constitution.get_requirements` — fetch documents by project/feature
- `constitution.get_blueprint` — fetch blueprints by project/feature
- `constitution.get_system_dependencies` — query Neo4j for system graph
- `constitution.get_impact_analysis` — traverse graph for downstream impact
- `constitution.search` — full-text + semantic search across all artifact types

**Resources:**
- `constitution://project/{id}/requirements`
- `constitution://project/{id}/blueprints`
- `constitution://work-order/{id}`
- `constitution://system/{id}/dependencies`

Authentication via API token (same as user auth token or dedicated MCP token).

**Commit:** `feat: add MCP server for IDE integration`

---

## Phase 12: Project Import

---

### Task 25: Git Repository Import

**Files:**
- Create: `app/services/importers/git_importer.rb`
- Create: `app/jobs/git_import_job.rb`
- Create: specs

Connects a repo, triggers codebase indexing, then asks the Refinery Agent to reverse-engineer requirements from the extracted artifacts.

**Commit:** `feat: add git repository import with AI requirement generation`

---

### Task 26: Jira Import

**Files:**
- Create: `app/services/importers/jira_importer.rb`
- Create: `app/jobs/jira_import_job.rb`
- Create: specs

Uses the Jira REST API (credentials provided by user) to pull epics, stories, tasks. Maps Jira statuses to Constitution's work order statuses. Creates work orders with Neo4j nodes.

**Commit:** `feat: add Jira import for work orders`

---

### Task 27: Document Upload Import

**Files:**
- Create: `app/services/importers/document_importer.rb`
- Create: specs

Accepts .md, .docx, .pdf uploads. Parses content (using `docx` gem for Word, `pdf-reader` for PDF). AI agent structures raw content into Refinery documents.

**Commit:** `feat: add document upload import (markdown, docx, pdf)`

---

## Phase 13: Polish & Integration

---

### Task 28: Application Layout & Navigation

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Create: `app/views/shared/_sidebar.html.erb`
- Create: `app/views/shared/_header.html.erb`

Build the main application shell:
- Left sidebar: project navigation (Refinery, Foundry, Planner, Validator, Systems)
- Top header: team name, notification bell, user avatar/menu
- Main content area
- Responsive layout with Tailwind

**Commit:** `feat: add application layout with sidebar navigation`

---

### Task 29: Project Dashboard

**Files:**
- Modify: `app/views/projects/show.html.erb`

Project show page becomes a dashboard:
- Recent activity feed
- Document/blueprint counts
- Open work orders summary
- Active drift alerts
- Linked systems

**Commit:** `feat: add project dashboard with activity feed and drift alerts`

---

### Task 30: End-to-End Smoke Test

**Files:**
- Create: `spec/system/full_lifecycle_spec.rb`

A system test (using Capybara + headless Chrome) that walks through the full lifecycle:

1. Sign up, create team
2. Create project (verify placeholder docs generated)
3. Edit a Feature Requirement document
4. Create a Feature Blueprint linked to the document
5. Generate work orders from the blueprint
6. Move a work order through the kanban board
7. Verify drift alert appears when document is edited after blueprint

```bash
docker compose run --rm web bundle exec rspec spec/system/
git add -A
git commit -m "test: add end-to-end smoke test for full lifecycle"
```

---

## Summary

| Phase | Tasks | What It Delivers |
|-------|-------|-----------------|
| 1: Skeleton | 1-4 | Docker, Rails, auth, project CRUD |
| 2: Refinery | 5-8 | Documents, versioning, comments, Tiptap editor |
| 3: Foundry | 9 | Blueprints, Mermaid diagrams |
| 4: Planner | 10-11 | Work orders, kanban board |
| 5: Knowledge Graph | 12-13 | Neo4j sync, drift detection |
| 6: AI Agents | 14-15 | AgentService, streaming chat sidebar |
| 7: Systems | 16-17 | Service registry, dependency map |
| 8: Validator | 18-19 | Feedback API, inbox UI |
| 9: Real-time | 20-21 | Channels, presence, notifications |
| 10: Codebase | 22-23 | Indexing, semantic search |
| 11: MCP | 24 | IDE integration |
| 12: Import | 25-27 | Git, Jira, document import |
| 13: Polish | 28-30 | Layout, dashboard, smoke test |
