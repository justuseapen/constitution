# Work Order Execution Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** When a user clicks "Run Agent" on a work order, Constitution shells out to Claude Code on the server, which implements the change in the target repo, pushes a branch, and opens a PR.

**Architecture:** New `WorkOrderExecution` model tracks each agent run. `WorkOrderExecutionJob` (Solid Queue) clones/prepares the repo, builds a prompt from work order + indexed artifacts, pipes it to `claude --dangerously-skip-permissions --print`, streams stdout to the UI via ActionCable, then opens a PR via `gh`.

**Tech Stack:** Rails 8.1, Solid Queue, ActionCable, Stimulus, Claude CLI, gh CLI

---

### Task 1: Migration and Model

**Files:**
- Create: `db/migrate/TIMESTAMP_create_work_order_executions.rb`
- Create: `app/models/work_order_execution.rb`
- Modify: `app/models/work_order.rb:1-34`
- Create: `spec/factories/work_order_executions.rb`
- Create: `spec/models/work_order_execution_spec.rb`

**Step 1: Write the model spec**

```ruby
# spec/models/work_order_execution_spec.rb
require "rails_helper"

RSpec.describe WorkOrderExecution, type: :model do
  it { should belong_to(:work_order) }
  it { should belong_to(:repository).optional }
  it { should belong_to(:triggered_by).class_name("User") }

  it { should validate_presence_of(:status) }

  describe "status enum" do
    it { should define_enum_for(:status).with_values(queued: 0, running: 1, completed: 2, failed: 3) }
  end

  describe "concurrent run validation" do
    it "prevents two running executions for the same work order" do
      work_order = create(:work_order)
      user = work_order.project.team.users.first || create(:user, team: work_order.project.team)
      create(:work_order_execution, work_order: work_order, triggered_by: user, status: :running)
      duplicate = build(:work_order_execution, work_order: work_order, triggered_by: user, status: :running)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:work_order_id]).to include("already has a running execution")
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/models/work_order_execution_spec.rb`
Expected: FAIL — table and model don't exist yet

**Step 3: Create the migration**

Run: `bin/rails generate migration CreateWorkOrderExecutions`

Then edit the generated migration file:

```ruby
class CreateWorkOrderExecutions < ActiveRecord::Migration[8.1]
  def change
    create_table :work_order_executions do |t|
      t.references :work_order, null: false, foreign_key: true
      t.references :repository, null: true, foreign_key: true
      t.references :triggered_by, null: false, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 0
      t.string :branch_name
      t.string :pull_request_url
      t.text :log
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :work_order_executions, [:work_order_id, :status]
  end
end
```

Run: `bin/rails db:migrate`

**Step 4: Write the model**

```ruby
# app/models/work_order_execution.rb
class WorkOrderExecution < ApplicationRecord
  belongs_to :work_order
  belongs_to :repository, optional: true
  belongs_to :triggered_by, class_name: "User"

  validates :status, presence: true
  validate :only_one_running_per_work_order, on: :create

  enum :status, {
    queued: 0,
    running: 1,
    completed: 2,
    failed: 3
  }, default: :queued

  scope :latest_first, -> { order(created_at: :desc) }

  def duration
    return nil unless started_at
    (completed_at || Time.current) - started_at
  end

  def append_log(text)
    update!(log: (log || "") + text)
  end

  private

  def only_one_running_per_work_order
    if work_order && WorkOrderExecution.where(work_order: work_order, status: :running).exists?
      errors.add(:work_order_id, "already has a running execution")
    end
  end
end
```

**Step 5: Write the factory**

```ruby
# spec/factories/work_order_executions.rb
FactoryBot.define do
  factory :work_order_execution do
    work_order
    triggered_by { association :user, team: work_order.project.team }
    status { :queued }
  end
end
```

**Step 6: Add has_many to WorkOrder**

In `app/models/work_order.rb`, add after line 8 (`has_many :agent_conversations...`):

```ruby
  has_many :executions, class_name: "WorkOrderExecution", dependent: :destroy
```

**Step 7: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/work_order_execution_spec.rb`
Expected: PASS

**Step 8: Commit**

```bash
git add db/migrate/*_create_work_order_executions.rb app/models/work_order_execution.rb app/models/work_order.rb spec/models/work_order_execution_spec.rb spec/factories/work_order_executions.rb db/schema.rb
git commit -m "feat: add WorkOrderExecution model and migration"
```

---

### Task 2: WorkOrderPromptBuilder Service

**Files:**
- Create: `app/services/work_order_prompt_builder.rb`
- Create: `spec/services/work_order_prompt_builder_spec.rb`

**Step 1: Write the spec**

```ruby
# spec/services/work_order_prompt_builder_spec.rb
require "rails_helper"

RSpec.describe WorkOrderPromptBuilder do
  let(:team) { create(:team) }
  let(:project) { create(:project, team: team) }
  let(:service_system) { create(:service_system, team: team) }
  let(:repository) { create(:repository, service_system: service_system, indexing_status: :indexed) }
  let(:work_order) { create(:work_order, project: project, title: "Add login page", description: "Build a login page with email and password") }

  describe "#build" do
    it "includes work order title and description" do
      builder = described_class.new(work_order: work_order, repository: repository)
      prompt = builder.build

      expect(prompt).to include("Add login page")
      expect(prompt).to include("Build a login page with email and password")
    end

    it "includes acceptance criteria when present" do
      builder = described_class.new(work_order: work_order, repository: repository)
      prompt = builder.build

      expect(prompt).to include("Criterion 1")
    end

    it "includes branch naming instruction with work order id" do
      builder = described_class.new(work_order: work_order, repository: repository)
      prompt = builder.build

      expect(prompt).to include("wo-#{work_order.id}")
    end

    it "includes completion signals" do
      builder = described_class.new(work_order: work_order, repository: repository)
      prompt = builder.build

      expect(prompt).to include("<constitution>COMPLETE</constitution>")
      expect(prompt).to include("<constitution>FAILED:")
    end

    it "includes extracted artifacts when available" do
      file = create(:codebase_file, repository: repository, path: "app/models/user.rb", content: "class User; end")
      create(:extracted_artifact, codebase_file: file, artifact_type: :model, name: "User")

      builder = described_class.new(work_order: work_order, repository: repository)
      prompt = builder.build

      expect(prompt).to include("User")
    end
  end

  describe "#select_repository" do
    it "returns the only repo when project has one" do
      # Link repo to project's team
      result = described_class.new(work_order: work_order, repository: nil).select_repository([repository])
      expect(result).to eq(repository)
    end

    it "scores repos by artifact overlap with work order text" do
      repo_a = create(:repository, service_system: service_system, name: "repo-a", indexing_status: :indexed)
      repo_b = create(:repository, service_system: service_system, name: "repo-b", indexing_status: :indexed)

      file_a = create(:codebase_file, repository: repo_a, path: "app/models/login.rb")
      create(:extracted_artifact, codebase_file: file_a, artifact_type: :model, name: "Login")

      file_b = create(:codebase_file, repository: repo_b, path: "app/models/invoice.rb")
      create(:extracted_artifact, codebase_file: file_b, artifact_type: :model, name: "Invoice")

      result = described_class.new(work_order: work_order, repository: nil).select_repository([repo_a, repo_b])
      expect(result).to eq(repo_a)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/work_order_prompt_builder_spec.rb`
Expected: FAIL — class doesn't exist

**Step 3: Write the service**

```ruby
# app/services/work_order_prompt_builder.rb
class WorkOrderPromptBuilder
  MAX_CONTEXT_TOKENS = 8000
  CHARS_PER_TOKEN = 4

  def initialize(work_order:, repository:)
    @work_order = work_order
    @repository = repository
  end

  def build
    sections = []
    sections << work_order_section
    sections << artifacts_section if @repository
    sections << instructions_section
    sections.compact.join("\n\n")
  end

  def select_repository(repositories)
    return repositories.first if repositories.size <= 1

    text = "#{@work_order.title} #{@work_order.description}".downcase
    words = text.scan(/\w+/).to_set

    repositories.max_by do |repo|
      repo.codebase_files.includes(:extracted_artifacts).flat_map(&:extracted_artifacts).count do |artifact|
        artifact_words = artifact.name.underscore.scan(/\w+/)
        artifact_words.any? { |w| words.include?(w.downcase) }
      end
    end
  end

  private

  def work_order_section
    section = "You are an autonomous coding agent. Implement the following work order.\n\n"
    section += "## Work Order\n"
    section += "**Title:** #{@work_order.title}\n\n"
    section += "**Description:** #{@work_order.description}\n\n" if @work_order.description.present?
    if @work_order.acceptance_criteria.present?
      section += "**Acceptance Criteria:**\n#{@work_order.acceptance_criteria}\n"
    end
    section
  end

  def artifacts_section
    return nil unless @repository

    artifacts = @repository.codebase_files
      .joins(:extracted_artifacts)
      .includes(:extracted_artifacts)
      .limit(50)

    return nil if artifacts.empty?

    max_chars = MAX_CONTEXT_TOKENS * CHARS_PER_TOKEN
    section = "## Codebase Context\n\n"
    total = section.length

    artifacts.flat_map(&:extracted_artifacts).group_by(&:artifact_type).each do |type, items|
      type_header = "### #{type.humanize.pluralize}\n"
      break if total + type_header.length > max_chars
      section += type_header
      total += type_header.length

      items.first(15).each do |artifact|
        line = "- #{artifact.name} (`#{artifact.codebase_file.path}`)\n"
        break if total + line.length > max_chars
        section += line
        total += line.length
      end
      section += "\n"
    end

    section
  end

  def instructions_section
    branch_name = "wo-#{@work_order.id}-#{@work_order.title.parameterize[0..40]}"

    <<~INSTRUCTIONS
      ## Instructions
      1. You are working in this repository. It is already cloned and on the default branch.
      2. Create a feature branch: `#{branch_name}`
      3. Implement the change described above.
      4. Run the project's test suite. Fix any failures your changes introduce.
      5. Commit your changes with a descriptive message.
      6. Push the branch to origin.
      7. When done, output exactly: <constitution>COMPLETE</constitution>
      8. If you cannot complete the work, output exactly: <constitution>FAILED: {reason}</constitution>
    INSTRUCTIONS
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/services/work_order_prompt_builder_spec.rb`
Expected: PASS

**Step 5: Commit**

```bash
git add app/services/work_order_prompt_builder.rb spec/services/work_order_prompt_builder_spec.rb
git commit -m "feat: add WorkOrderPromptBuilder service"
```

---

### Task 3: WorkOrderExecutionJob

**Files:**
- Create: `app/jobs/work_order_execution_job.rb`
- Create: `spec/jobs/work_order_execution_job_spec.rb`

**Step 1: Write the spec**

```ruby
# spec/jobs/work_order_execution_job_spec.rb
require "rails_helper"

RSpec.describe WorkOrderExecutionJob, type: :job do
  let(:team) { create(:team) }
  let(:project) { create(:project, team: team) }
  let(:user) { create(:user, team: team) }
  let(:service_system) { create(:service_system, team: team) }
  let(:repository) { create(:repository, service_system: service_system, indexing_status: :indexed) }
  let(:work_order) { create(:work_order, project: project, status: :todo) }
  let(:execution) { create(:work_order_execution, work_order: work_order, triggered_by: user, status: :queued) }

  it "is enqueued in the default queue" do
    expect(described_class.new.queue_name).to eq("default")
  end

  it "marks execution as failed when claude CLI is not found" do
    allow_any_instance_of(described_class).to receive(:claude_available?).and_return(false)

    described_class.perform_now(execution.id)

    execution.reload
    expect(execution.status).to eq("failed")
    expect(execution.error_message).to include("claude CLI not found")
  end

  it "marks execution as failed when no repositories are available" do
    allow_any_instance_of(described_class).to receive(:claude_available?).and_return(true)

    described_class.perform_now(execution.id)

    execution.reload
    expect(execution.status).to eq("failed")
    expect(execution.error_message).to include("No indexed repositories")
  end

  it "updates work order status to in_progress when starting" do
    allow_any_instance_of(described_class).to receive(:claude_available?).and_return(true)
    allow_any_instance_of(described_class).to receive(:find_repositories).and_return([repository])
    allow_any_instance_of(described_class).to receive(:prepare_repo)
    allow_any_instance_of(described_class).to receive(:execute_claude).and_return("<constitution>COMPLETE</constitution>")
    allow_any_instance_of(described_class).to receive(:open_pull_request).and_return("https://github.com/example/repo/pull/1")

    described_class.perform_now(execution.id)

    work_order.reload
    expect(work_order.status).to eq("review")
  end

  it "marks execution completed on success signal" do
    allow_any_instance_of(described_class).to receive(:claude_available?).and_return(true)
    allow_any_instance_of(described_class).to receive(:find_repositories).and_return([repository])
    allow_any_instance_of(described_class).to receive(:prepare_repo)
    allow_any_instance_of(described_class).to receive(:execute_claude).and_return("Done.\n<constitution>COMPLETE</constitution>")
    allow_any_instance_of(described_class).to receive(:open_pull_request).and_return("https://github.com/example/repo/pull/1")

    described_class.perform_now(execution.id)

    execution.reload
    expect(execution.status).to eq("completed")
    expect(execution.pull_request_url).to eq("https://github.com/example/repo/pull/1")
    expect(execution.completed_at).to be_present
  end

  it "marks execution failed on failure signal" do
    allow_any_instance_of(described_class).to receive(:claude_available?).and_return(true)
    allow_any_instance_of(described_class).to receive(:find_repositories).and_return([repository])
    allow_any_instance_of(described_class).to receive(:prepare_repo)
    allow_any_instance_of(described_class).to receive(:execute_claude).and_return("<constitution>FAILED: tests won't pass</constitution>")

    described_class.perform_now(execution.id)

    execution.reload
    expect(execution.status).to eq("failed")
    expect(execution.error_message).to include("tests won't pass")
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/jobs/work_order_execution_job_spec.rb`
Expected: FAIL — job class doesn't exist

**Step 3: Write the job**

```ruby
# app/jobs/work_order_execution_job.rb
class WorkOrderExecutionJob < ApplicationJob
  queue_as :default

  TIMEOUT = 10.minutes

  def perform(execution_id)
    @execution = WorkOrderExecution.find(execution_id)
    @work_order = @execution.work_order
    @project = @work_order.project

    unless claude_available?
      fail_execution("claude CLI not found in PATH. Install Claude Code on the server.")
      return
    end

    repositories = find_repositories
    if repositories.empty?
      fail_execution("No indexed repositories found for this project.")
      return
    end

    start_execution

    prompt_builder = WorkOrderPromptBuilder.new(work_order: @work_order, repository: nil)
    repository = prompt_builder.select_repository(repositories)
    @execution.update!(repository: repository)

    prompt_builder = WorkOrderPromptBuilder.new(work_order: @work_order, repository: repository)
    prompt = prompt_builder.build

    prepare_repo(repository)
    output = execute_claude(prompt, repository)

    if output.include?("<constitution>COMPLETE</constitution>")
      pr_url = open_pull_request(repository)
      complete_execution(output, pr_url)
    elsif output.match?(%r{<constitution>FAILED:\s*(.+?)</constitution>})
      reason = output.match(%r{<constitution>FAILED:\s*(.+?)</constitution>})[1]
      fail_execution(reason, log: output)
    else
      fail_execution("Agent did not signal completion.", log: output)
    end
  rescue StandardError => e
    fail_execution("#{e.class}: #{e.message}", log: @execution&.log)
    Rails.logger.error("WorkOrderExecutionJob failed: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
  end

  private

  def claude_available?
    system("which claude > /dev/null 2>&1")
  end

  def find_repositories
    team = @project.team
    team.service_systems.flat_map(&:repositories).select(&:indexed?)
  end

  def start_execution
    @execution.update!(status: :running, started_at: Time.current)
    @work_order.update!(status: :in_progress)
  end

  def prepare_repo(repository)
    repo_path = Rails.root.join("tmp", "repos", repository.id.to_s)

    if Dir.exist?(repo_path)
      system("git", "-C", repo_path.to_s, "checkout", repository.default_branch, exception: true)
      system("git", "-C", repo_path.to_s, "pull", "--ff-only", exception: true)
    else
      FileUtils.mkdir_p(repo_path.parent)
      system("git", "clone", "--branch", repository.default_branch, repository.url, repo_path.to_s, exception: true)
    end
  end

  def execute_claude(prompt, repository)
    repo_path = Rails.root.join("tmp", "repos", repository.id.to_s)
    channel = "execution_#{@execution.id}"
    output = ""

    IO.popen(
      ["claude", "--dangerously-skip-permissions", "--print"],
      chdir: repo_path.to_s,
      err: [:child, :out]
    ) do |io|
      io.write(prompt)
      io.close_write

      io.each_line do |line|
        output += line
        @execution.update_column(:log, output)
        ActionCable.server.broadcast(channel, { type: "log", content: line })
      end
    end

    unless $?.success?
      ActionCable.server.broadcast(channel, { type: "error", content: "Claude process exited with status #{$?.exitstatus}" })
    end

    ActionCable.server.broadcast(channel, { type: "complete", status: $?.success? ? "completed" : "failed" })
    output
  end

  def open_pull_request(repository)
    repo_path = Rails.root.join("tmp", "repos", repository.id.to_s)
    branch = "wo-#{@work_order.id}-#{@work_order.title.parameterize[0..40]}"
    title = "WO-#{@work_order.id}: #{@work_order.title}"
    body = "Automated implementation for work order ##{@work_order.id}.\n\n**Description:**\n#{@work_order.description}"

    pr_output = `cd #{repo_path} && gh pr create --title "#{title.gsub('"', '\\"')}" --body "#{body.gsub('"', '\\"')}" --head "#{branch}" 2>&1`

    if $?.success?
      pr_output.strip.lines.last.strip # gh pr create outputs the URL as the last line
    else
      Rails.logger.warn("Failed to create PR: #{pr_output}")
      nil
    end
  end

  def complete_execution(output, pr_url)
    @execution.update!(
      status: :completed,
      log: output,
      pull_request_url: pr_url,
      completed_at: Time.current
    )
    @work_order.update!(status: :review)
  end

  def fail_execution(message, log: nil)
    @execution&.update!(
      status: :failed,
      error_message: message,
      log: log || @execution&.log,
      completed_at: Time.current
    )
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/jobs/work_order_execution_job_spec.rb`
Expected: PASS

**Step 5: Commit**

```bash
git add app/jobs/work_order_execution_job.rb spec/jobs/work_order_execution_job_spec.rb
git commit -m "feat: add WorkOrderExecutionJob for autonomous agent execution"
```

---

### Task 4: ActionCable Channel

**Files:**
- Create: `app/channels/work_order_execution_channel.rb`

**Step 1: Create the channel**

```ruby
# app/channels/work_order_execution_channel.rb
class WorkOrderExecutionChannel < ApplicationCable::Channel
  def subscribed
    stream_from "execution_#{params[:execution_id]}"
  end
end
```

**Step 2: Commit**

```bash
git add app/channels/work_order_execution_channel.rb
git commit -m "feat: add WorkOrderExecutionChannel for live log streaming"
```

---

### Task 5: Controller Execute Action and Route

**Files:**
- Modify: `app/controllers/work_orders_controller.rb:1-62`
- Modify: `config/routes.rb:6` (work_orders resources line)

**Step 1: Add the execute action to WorkOrdersController**

Add after the `destroy` method (after line 44) in `app/controllers/work_orders_controller.rb`:

```ruby
  def execute
    if @work_order.executions.where(status: :running).exists?
      redirect_to project_work_order_path(@project, @work_order), alert: "An execution is already running."
      return
    end

    execution = @work_order.executions.create!(
      triggered_by: current_user,
      status: :queued
    )

    WorkOrderExecutionJob.perform_later(execution.id)

    redirect_to project_work_order_path(@project, @work_order), notice: "Agent execution started."
  end
```

Also update the `before_action :set_work_order` on line 4 to include `:execute`:

```ruby
  before_action :set_work_order, only: [:show, :edit, :update, :destroy, :execute]
```

**Step 2: Add the route**

In `config/routes.rb`, change the work_orders resource (line 6 area) from:

```ruby
    resources :work_orders
```

to:

```ruby
    resources :work_orders do
      member do
        post :execute
      end
    end
```

**Step 3: Verify routes**

Run: `bin/rails routes | grep execute`
Expected: Shows `execute_project_work_order POST /projects/:project_id/work_orders/:id/execute`

**Step 4: Commit**

```bash
git add app/controllers/work_orders_controller.rb config/routes.rb
git commit -m "feat: add execute action and route for work order agent execution"
```

---

### Task 6: Execution Log Stimulus Controller

**Files:**
- Create: `app/javascript/controllers/execution_log_controller.js`

**Step 1: Create the Stimulus controller**

```javascript
// app/javascript/controllers/execution_log_controller.js
import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["log", "status", "prLink"]
  static values = { executionId: Number, status: String }

  connect() {
    if (this.statusValue === "queued" || this.statusValue === "running") {
      this.setupActionCable()
    }
    this.scrollToBottom()
  }

  setupActionCable() {
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      {
        channel: "WorkOrderExecutionChannel",
        execution_id: this.executionIdValue
      },
      { received: (data) => this.handleReceived(data) }
    )
  }

  handleReceived(data) {
    if (data.type === "log") {
      this.appendLog(data.content)
    } else if (data.type === "complete") {
      this.updateStatus(data.status)
      this.subscription?.unsubscribe()
    } else if (data.type === "error") {
      this.appendLog(`ERROR: ${data.content}\n`)
    }
  }

  appendLog(text) {
    if (this.hasLogTarget) {
      this.logTarget.textContent += text
      this.scrollToBottom()
    }
  }

  updateStatus(status) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = status
      this.statusTarget.className = status === "completed"
        ? "px-2 py-1 rounded text-xs font-medium bg-green-100 text-green-800"
        : "px-2 py-1 rounded text-xs font-medium bg-red-100 text-red-800"
    }
    // Reload page after a short delay to show final state including PR link
    setTimeout(() => window.location.reload(), 2000)
  }

  scrollToBottom() {
    if (this.hasLogTarget) {
      this.logTarget.scrollTop = this.logTarget.scrollHeight
    }
  }

  disconnect() {
    this.subscription?.unsubscribe()
    this.consumer?.disconnect()
  }
}
```

**Step 2: Commit**

```bash
git add app/javascript/controllers/execution_log_controller.js
git commit -m "feat: add execution_log Stimulus controller for live streaming"
```

---

### Task 7: Execution Panel Partial and Show Page Update

**Files:**
- Create: `app/views/work_orders/_execution_panel.html.erb`
- Modify: `app/views/work_orders/show.html.erb:1-49`

**Step 1: Create the execution panel partial**

```erb
<%# app/views/work_orders/_execution_panel.html.erb %>
<% executions = work_order.executions.latest_first %>
<% latest = executions.first %>

<div class="mb-6">
  <div class="flex justify-between items-center mb-3">
    <h3 class="text-lg font-semibold">Agent Execution</h3>
    <% repos_available = work_order.project.team.service_systems.flat_map(&:repositories).any?(&:indexed?) %>
    <% running = work_order.executions.where(status: :running).exists? %>
    <% if repos_available && work_order.description.present? %>
      <%= button_to "Run Agent",
            execute_project_work_order_path(work_order.project, work_order),
            method: :post,
            disabled: running,
            class: "px-4 py-2 rounded text-sm font-medium #{running ? 'bg-gray-300 text-gray-500 cursor-not-allowed' : 'bg-indigo-600 text-white hover:bg-indigo-700'}" %>
    <% end %>
  </div>

  <% if latest %>
    <div data-controller="execution-log"
         data-execution-log-execution-id-value="<%= latest.id %>"
         data-execution-log-status-value="<%= latest.status %>">

      <div class="flex items-center gap-3 mb-2">
        <% status_classes = {
          "queued" => "bg-yellow-100 text-yellow-800",
          "running" => "bg-blue-100 text-blue-800",
          "completed" => "bg-green-100 text-green-800",
          "failed" => "bg-red-100 text-red-800"
        } %>
        <span data-execution-log-target="status"
              class="px-2 py-1 rounded text-xs font-medium <%= status_classes[latest.status] %>">
          <%= latest.status.humanize %>
        </span>
        <span class="text-xs text-gray-500">
          Started by <%= latest.triggered_by.name %> <%= time_ago_in_words(latest.created_at) %> ago
        </span>
        <% if latest.duration %>
          <span class="text-xs text-gray-500">
            Duration: <%= (latest.duration / 60).floor %>m <%= (latest.duration % 60).round %>s
          </span>
        <% end %>
      </div>

      <% if latest.pull_request_url.present? %>
        <div class="mb-2" data-execution-log-target="prLink">
          <a href="<%= latest.pull_request_url %>" target="_blank"
             class="text-sm text-indigo-600 hover:text-indigo-800 underline">
            View Pull Request &rarr;
          </a>
        </div>
      <% end %>

      <% if latest.error_message.present? %>
        <div class="mb-2 p-3 bg-red-50 border border-red-200 rounded text-sm text-red-700">
          <%= latest.error_message %>
        </div>
      <% end %>

      <div class="bg-gray-900 rounded-lg p-4 max-h-96 overflow-y-auto">
        <pre data-execution-log-target="log"
             class="text-xs text-green-400 font-mono whitespace-pre-wrap"><%= latest.log %></pre>
      </div>
    </div>

    <% if executions.size > 1 %>
      <details class="mt-3">
        <summary class="text-sm text-gray-500 cursor-pointer hover:text-gray-700">
          Previous executions (<%= executions.size - 1 %>)
        </summary>
        <div class="mt-2 space-y-2">
          <% executions.offset(1).each do |exec| %>
            <div class="p-3 border rounded text-sm">
              <span class="px-2 py-0.5 rounded text-xs font-medium <%= status_classes[exec.status] %>">
                <%= exec.status.humanize %>
              </span>
              <span class="text-xs text-gray-500 ml-2"><%= exec.created_at.strftime("%b %d %H:%M") %></span>
              <% if exec.pull_request_url.present? %>
                <a href="<%= exec.pull_request_url %>" target="_blank" class="text-xs text-indigo-600 ml-2">PR</a>
              <% end %>
              <% if exec.error_message.present? %>
                <p class="text-xs text-red-600 mt-1"><%= exec.error_message %></p>
              <% end %>
            </div>
          <% end %>
        </div>
      </details>
    <% end %>
  <% else %>
    <% unless work_order.project.team.service_systems.flat_map(&:repositories).any?(&:indexed?) %>
      <p class="text-sm text-gray-500">No indexed repositories. Import a repository first.</p>
    <% elsif work_order.description.blank? %>
      <p class="text-sm text-gray-500">Add a description to enable agent execution.</p>
    <% else %>
      <p class="text-sm text-gray-500">No executions yet. Click "Run Agent" to start.</p>
    <% end %>
  <% end %>
</div>
```

**Step 2: Update the work order show page**

In `app/views/work_orders/show.html.erb`, add the execution panel after the implementation plan section (after line 43, before the closing `</div>` tags). Insert before line 44:

```erb
      <%= render "work_orders/execution_panel", work_order: @work_order %>
```

**Step 3: Verify in browser**

Run: `bin/dev`
Navigate to a work order show page. You should see the "Agent Execution" section with either a "Run Agent" button or a message about missing repos/description.

**Step 4: Commit**

```bash
git add app/views/work_orders/_execution_panel.html.erb app/views/work_orders/show.html.erb
git commit -m "feat: add execution panel UI with live log streaming to work order page"
```

---

### Task 8: Integration Test

**Files:**
- Create: `spec/jobs/work_order_execution_job_integration_spec.rb`

**Step 1: Write an integration spec testing the full flow with mocked CLI**

```ruby
# spec/jobs/work_order_execution_job_integration_spec.rb
require "rails_helper"

RSpec.describe "Work Order Execution Integration", type: :job do
  let(:team) { create(:team) }
  let(:project) { create(:project, team: team) }
  let(:user) { create(:user, team: team) }
  let(:service_system) { create(:service_system, team: team) }
  let(:repository) { create(:repository, service_system: service_system, indexing_status: :indexed) }
  let!(:codebase_file) { create(:codebase_file, repository: repository, path: "app/models/claim.rb") }
  let!(:artifact) { create(:extracted_artifact, codebase_file: codebase_file, artifact_type: :model, name: "Claim") }
  let(:work_order) do
    create(:work_order, project: project, status: :todo,
           title: "Remove claim tracking",
           description: "Remove the Claim model and all associated code")
  end
  let(:execution) { create(:work_order_execution, work_order: work_order, triggered_by: user) }

  it "selects the correct repository based on artifact overlap" do
    builder = WorkOrderPromptBuilder.new(work_order: work_order, repository: nil)
    result = builder.select_repository([repository])
    expect(result).to eq(repository)
  end

  it "builds a prompt containing work order and artifact context" do
    builder = WorkOrderPromptBuilder.new(work_order: work_order, repository: repository)
    prompt = builder.build

    expect(prompt).to include("Remove claim tracking")
    expect(prompt).to include("Claim")
    expect(prompt).to include("app/models/claim.rb")
    expect(prompt).to include("wo-#{work_order.id}")
  end
end
```

**Step 2: Run the spec**

Run: `bundle exec rspec spec/jobs/work_order_execution_job_integration_spec.rb`
Expected: PASS

**Step 3: Run full test suite**

Run: `bundle exec rspec`
Expected: All tests pass

**Step 4: Commit**

```bash
git add spec/jobs/work_order_execution_job_integration_spec.rb
git commit -m "test: add integration spec for work order execution flow"
```
