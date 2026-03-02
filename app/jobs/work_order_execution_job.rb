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
      pr_output.strip.lines.last.strip
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
