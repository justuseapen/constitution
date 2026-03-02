# Work Order Execution — Design

Autonomous agent loop that implements code changes from Constitution work orders by shelling out to Claude Code on the server.

## Decisions

- **Execution environment**: Server-side, Solid Queue worker shells out to `claude --dangerously-skip-permissions --print`
- **Trigger**: Explicit "Run Agent" button on the work order page (not auto-triggered by status change)
- **Repo selection**: Agent decides from context — score project repositories by artifact overlap with work order text, pick the best match
- **Output**: Feature branch + GitHub PR, work order moves to `review`
- **Observability**: Stream Claude Code stdout to the UI in real-time via ActionCable

## Data Model

New model: `WorkOrderExecution`

| Field | Type | Notes |
|-------|------|-------|
| work_order_id | references | required |
| repository_id | references | nullable until repo is selected |
| triggered_by_id | references (User) | who clicked the button |
| status | enum | queued, running, completed, failed |
| branch_name | string | e.g. `wo-42-add-progress-percentage` |
| pull_request_url | string | set after PR creation |
| log | text | full agent stdout |
| error_message | text | set on failure |
| started_at | datetime | |
| completed_at | datetime | |

One work order can have many executions (retry history). Only one execution can be `running` per work order at a time.

## Execution Flow

1. User clicks "Run Agent" on work order show page
2. Controller creates `WorkOrderExecution` (status: `queued`), enqueues `WorkOrderExecutionJob`
3. Job updates execution to `running`, work order to `in_progress`
4. **Pick repo**: Score each project repository by how many extracted artifact names appear in the work order title + description. Single repo = skip scoring.
5. **Build prompt**: Assemble work order fields + relevant extracted artifacts + code chunks (via ContextBuilder) into a structured prompt
6. **Prepare repo**: `git checkout {default_branch} && git pull` in `tmp/repos/{repo_id}`
7. **Execute**: Shell out to `claude --dangerously-skip-permissions --print` with the prompt piped to stdin, working directory set to repo clone. Capture stdout line-by-line, broadcast each line to ActionCable channel `execution_{id}`.
8. **Detect completion**: Scan output for `<constitution>COMPLETE</constitution>` or `<constitution>FAILED: reason</constitution>`
9. **Open PR**: Run `gh pr create` from the repo directory. Store PR URL on execution.
10. **Finalize**: Mark execution `completed` or `failed`. Move work order to `review` on success, leave at `in_progress` on failure.

## Prompt Structure

```
You are an autonomous coding agent. Implement the following work order.

## Work Order
Title: {title}
Description: {description}
Acceptance Criteria:
{acceptance_criteria}

## Codebase Context
{extracted artifacts relevant to this change}
{semantic code chunks if embeddings available}

## Instructions
1. You are working in {repo_path}. The repo is already cloned and on the default branch.
2. Create a feature branch: wo-{work_order_id}-{slugified-title}
3. Implement the change described above.
4. Run the project's test suite. Fix any failures your changes introduce.
5. Commit your changes with a descriptive message.
6. Push the branch to origin.
7. When done, output exactly: <constitution>COMPLETE</constitution>
8. If you cannot complete the work, output: <constitution>FAILED: {reason}</constitution>
```

Context budget: ~8k tokens of codebase context via ContextBuilder.

## UI

### Work order show page additions

- **"Run Agent" button**: Visible when work order has a description and project has indexed repos. Disabled while an execution is running.
- **Execution log panel**: Below work order details. Shows status badge, live-streaming monospace log, PR link on completion, timestamps and duration.
- **Execution history**: Multiple executions shown as collapsible list, most recent expanded.

### ActionCable

- `WorkOrderExecutionChannel` streams `execution_{id}`
- Stimulus controller subscribes on connect, appends log lines, updates status badge on completion
- Same pattern as existing `AgentChatChannel`

## Error Handling

- **Timeout**: 10-minute default. On timeout, mark execution `failed`.
- **Concurrent runs**: Only one `running` execution per work order. Controller enforces this.
- **Git state**: Job resets to default branch before each run. Feature branch created fresh.
- **Push auth**: Requires git credentials on server (SSH key or credential helper). Job fails gracefully if push fails.
- **Claude CLI missing**: Job checks for `claude` in PATH before starting. Fails with descriptive error.
- **No repos**: Button hidden if project has no repositories.
- **No completion signal**: If Claude stops without signaling, treat as failed.

## New Files

- `db/migrate/..._create_work_order_executions.rb`
- `app/models/work_order_execution.rb`
- `app/jobs/work_order_execution_job.rb`
- `app/services/work_order_prompt_builder.rb`
- `app/channels/work_order_execution_channel.rb`
- `app/javascript/controllers/execution_log_controller.js` (Stimulus)
- `app/views/work_orders/_execution_panel.html.erb`
- Updates to `app/views/work_orders/show.html.erb`
- Updates to `app/controllers/work_orders_controller.rb` (execute action)
- Updates to `config/routes.rb` (execute member route)
- Specs for model, job, prompt builder
