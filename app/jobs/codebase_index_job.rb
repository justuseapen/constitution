class CodebaseIndexJob < ApplicationJob
  queue_as :default

  def perform(repository_id)
    repository = Repository.find(repository_id)
    repository.update!(indexing_status: :indexing)

    clone_or_pull(repository)
    index_files(repository)
    generate_embeddings(repository)

    repository.update!(indexing_status: :indexed, last_indexed_at: Time.current)
  rescue StandardError => e
    repository&.update(indexing_status: :failed)
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

    Dir.glob(File.join(repo_path, "**", "*")).each do |file_path|
      next if File.directory?(file_path)
      next if skip_file?(file_path)

      relative_path = file_path.sub("#{repo_path}/", "")
      content = File.read(file_path, encoding: "UTF-8") rescue next
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
      parser.parse.each do |artifact_data|
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
end
