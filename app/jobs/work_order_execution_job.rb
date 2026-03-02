require "open3"

class WorkOrderExecutionJob < ApplicationJob
  queue_as :default

  TIMEOUT = 10.minutes

  def perform(execution_id, include_feedback: false)
    @execution = WorkOrderExecution.find(execution_id)
    @include_feedback = include_feedback
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

    prompt_builder = WorkOrderPromptBuilder.new(work_order: @work_order, repository: nil, execution: @execution, include_feedback: @include_feedback)
    repository = prompt_builder.select_repository(repositories)

    prompt_builder = WorkOrderPromptBuilder.new(work_order: @work_order, repository: repository, execution: @execution, include_feedback: @include_feedback)
    @execution.update!(repository: repository, branch_name: prompt_builder.branch_name)

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
  rescue Timeout::Error
    fail_execution("Execution timed out after #{TIMEOUT / 60} minutes.", log: @execution&.log)
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
    lines_since_flush = 0
    last_flush = Time.current

    Timeout.timeout(TIMEOUT) do
      IO.popen(
        [ "claude", "--dangerously-skip-permissions", "--print" ],
        "r+",
        chdir: repo_path.to_s,
        err: [ :child, :out ]
      ) do |io|
        @execution.update_column(:pid, io.pid)
        io.write(prompt)
        io.close_write

        io.each_line do |line|
          output += line
          lines_since_flush += 1
          ActionCable.server.broadcast(channel, { type: "log", content: line })

          if lines_since_flush >= 50 || Time.current - last_flush >= 2
            @execution.update_column(:log, output)
            lines_since_flush = 0
            last_flush = Time.current
          end
        end
      end
    end

    # Final flush to ensure all output is persisted
    @execution.update_column(:log, output)

    unless $?.success?
      ActionCable.server.broadcast(channel, { type: "error", content: "Claude process exited with status #{$?.exitstatus}" })
    end

    ActionCable.server.broadcast(channel, { type: "complete", status: $?.success? ? "completed" : "failed" })
    output
  end

  def open_pull_request(repository)
    branch = @execution.branch_name
    title = "WO-#{@work_order.id}: #{@work_order.title}"
    body = "Automated implementation for work order ##{@work_order.id}.\n\n**Description:**\n#{@work_order.description}"

    provider = Vcs::ProviderFactory.for(repository)
    provider.create_merge_request(branch: branch, title: title, body: body)
  rescue RuntimeError => e
    Rails.logger.warn("Failed to create PR/MR: #{e.message}")
    nil
  end

  def complete_execution(output, pr_url)
    @execution.update!(
      status: :completed,
      log: output,
      pull_request_url: pr_url,
      completed_at: Time.current
    )
    @work_order.update!(status: :review)

    pr_msg = pr_url ? " PR: #{pr_url}" : ""
    notify_triggered_user("Work order '#{@work_order.title}' completed.#{pr_msg}")

    if pr_url.present?
      @execution.update!(pr_status: :pr_open)
      PrValidationJob.perform_later(@execution.id)
      PrStatusTrackingJob.set(wait: 5.minutes).perform_later
    end
  end

  def fail_execution(message, log: nil)
    @execution&.update!(
      status: :failed,
      error_message: message,
      log: log || @execution&.log,
      completed_at: Time.current
    )
    @work_order&.update!(status: :todo) if @work_order&.in_progress?

    notify_triggered_user("Work order '#{@work_order&.title}' execution failed: #{message}")
  end

  def notify_triggered_user(message)
    return unless @execution&.triggered_by_id

    Notification.create!(
      user_id: @execution.triggered_by_id,
      message: message,
      notifiable: @work_order
    )
  rescue StandardError => e
    Rails.logger.warn("Failed to create notification: #{e.message}")
  end
end
