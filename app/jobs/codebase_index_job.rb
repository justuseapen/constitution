class CodebaseIndexJob < ApplicationJob
  queue_as :default

  def perform(repository_id, project_id: nil, user_id: nil)
    @repository = Repository.find(repository_id)
    @project_id = project_id
    @repository.update!(indexing_status: :indexing)
    broadcast_progress("cloning", "Cloning repository...")

    clone_or_pull(@repository)
    broadcast_progress("parsing_files", "Parsing files...")

    index_files(@repository)
    broadcast_progress("generating_embeddings", "Generating embeddings...")

    generate_embeddings(@repository)

    infer_dependencies(@repository)

    @repository.update!(indexing_status: :indexed, last_indexed_at: Time.current)
    broadcast_progress("complete", "Indexing complete")
    notify_user(user_id, "Repository '#{@repository.name}' indexing complete. #{@repository.codebase_files.count} files indexed.")

    if project_id && user_id
      GenerateRequirementsJob.perform_later(
        project_id: project_id,
        user_id: user_id,
        repository_id: @repository.id
      )
    end
  rescue StandardError => e
    @repository&.update(indexing_status: :failed)
    broadcast_progress("failed", "Indexing failed: #{e.message}")
    notify_user(user_id, "Repository '#{@repository&.name}' indexing failed: #{e.message}")
    Rails.logger.error("Codebase indexing failed for repo #{repository_id}: #{e.message}")
    raise
  end

  private

  def clone_or_pull(repository)
    repo_path = Rails.root.join("tmp", "repos", repository.id.to_s)

    if Dir.exist?(repo_path)
      system("git", "-C", repo_path.to_s, "pull", "--ff-only", exception: true)
    else
      FileUtils.mkdir_p(repo_path.parent)
      system("git", "clone", "--depth=1", "--branch", repository.default_branch, repository.url, repo_path.to_s, exception: true)
    end
  end

  def index_files(repository)
    repo_path = Rails.root.join("tmp", "repos", repository.id.to_s)

    all_files = Dir.glob(File.join(repo_path, "**", "*")).reject { |f| File.directory?(f) }
    total_files = all_files.size
    processed = 0

    all_files.each do |file_path|
      relative_path = file_path.sub("#{repo_path}/", "")
      next if skip_file?(relative_path)

      processed += 1
      broadcast_progress("parsing_files", "#{processed}/#{total_files} files") if (processed % 25).zero?
      content = File.read(file_path, encoding: "UTF-8") rescue next
      next if content.include?("\x00") # skip binary files
      sha = Digest::SHA256.hexdigest(content)

      codebase_file = repository.codebase_files.find_or_initialize_by(path: relative_path)
      next if codebase_file.persisted? && codebase_file.sha == sha

      codebase_file.update!(
        content: content,
        language: detect_language(file_path),
        sha: sha,
        last_indexed_at: Time.current
      )

      # Parse and extract artifacts
      parser = CodeParser.new(codebase_file)

      codebase_file.extracted_artifacts.destroy_all
      seen_artifacts = Set.new
      parser.parse.each do |artifact_data|
        key = [ artifact_data[:artifact_type], artifact_data[:name] ]
        next if seen_artifacts.include?(key)
        seen_artifacts.add(key)

        codebase_file.extracted_artifacts.create!(
          artifact_type: artifact_data[:artifact_type],
          name: artifact_data[:name],
          metadata: artifact_data.except(:artifact_type, :name, :start_line, :end_line)
        )
      end

      # Create chunks
      codebase_file.codebase_chunks.destroy_all
      parser.chunk.each do |chunk_data|
        codebase_file.codebase_chunks.create!(
          content: chunk_data[:content],
          chunk_type: chunk_data[:chunk_type],
          start_line: chunk_data[:start_line],
          end_line: chunk_data[:end_line]
        )
      end
    end
  end

  def generate_embeddings(repository)
    repository.codebase_files.includes(:codebase_chunks).find_each do |file|
      file.codebase_chunks.where(embedding: nil).find_each do |chunk|
        next unless chunk.content.present?

        begin
          response = OPENROUTER_CLIENT.embeddings(
            parameters: { model: "openai/text-embedding-3-small", input: chunk.content.truncate(8000) }
          )
          embedding = response.dig("data", 0, "embedding")
          chunk.update!(embedding: embedding) if embedding
        rescue StandardError => e
          Rails.logger.warn("Embedding failed for chunk #{chunk.id}: #{e.message}")
        end
      end
    end
  end

  def infer_dependencies(repository)
    DependencyInferrer.new(repository).infer!
  rescue StandardError => e
    Rails.logger.warn("Dependency inference failed for repo #{repository.id}: #{e.message}")
  end

  def skip_file?(path)
    skip_patterns = [
      /node_modules/, /\.git\//, /vendor\//, /tmp\//, /log\//,
      /\.png$/, /\.jpg$/, /\.jpeg$/, /\.gif$/, /\.svg$/, /\.ico$/,
      /\.woff/, /\.ttf/, /\.eot/, /\.map$/, /\.lock$/,
      /\.min\.js$/, /\.min\.css$/
    ]
    skip_patterns.any? { |pattern| path.match?(pattern) }
  end

  def detect_language(path)
    ext = File.extname(path).downcase
    {
      ".rb" => "ruby", ".js" => "javascript", ".ts" => "typescript",
      ".py" => "python", ".yml" => "yaml", ".yaml" => "yaml",
      ".json" => "json", ".proto" => "protobuf", ".css" => "css",
      ".html" => "html", ".erb" => "erb", ".md" => "markdown"
    }[ext] || "unknown"
  end

  def notify_user(user_id, message)
    return unless user_id

    Notification.create!(
      user_id: user_id,
      message: message,
      notifiable: @repository
    )
  rescue StandardError => e
    Rails.logger.warn("Failed to create notification: #{e.message}")
  end

  def broadcast_progress(phase, message)
    return unless @project_id

    ActionCable.server.broadcast("project_#{@project_id}", {
      type: "indexing_progress",
      repository_id: @repository.id,
      repository_name: @repository.name,
      status: @repository.indexing_status,
      phase: phase,
      progress: message
    })
  end
end
