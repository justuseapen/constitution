class CodeParser
  LANGUAGE_MAP = {
    ".rb" => :ruby,
    ".js" => :javascript,
    ".ts" => :typescript,
    ".yml" => :yaml,
    ".yaml" => :yaml,
    ".proto" => :protobuf,
    ".json" => :json
  }.freeze

  def initialize(codebase_file)
    @file = codebase_file
    @content = codebase_file.content
    @language = detect_language
  end

  def parse
    return [] unless @content.present?

    case @language
    when :ruby then parse_ruby
    when :javascript, :typescript then parse_javascript
    when :yaml then parse_yaml
    else []
    end
  end

  def chunk(max_lines: 50)
    return [] unless @content.present?

    lines = @content.lines
    chunks = []

    # First, try semantic chunking based on extracted artifacts
    artifacts = parse
    artifacts.each do |artifact|
      if artifact[:start_line] && artifact[:end_line]
        chunk_content = lines[(artifact[:start_line]-1)..(artifact[:end_line]-1)]&.join
        next unless chunk_content.present?
        chunks << {
          content: chunk_content,
          chunk_type: artifact[:artifact_type],
          start_line: artifact[:start_line],
          end_line: artifact[:end_line]
        }
      end
    end

    # Fall back to sliding window for uncovered regions
    if chunks.empty?
      lines.each_slice(max_lines).with_index do |slice, i|
        start_line = i * max_lines + 1
        end_line = start_line + slice.length - 1
        chunks << {
          content: slice.join,
          chunk_type: "block",
          start_line: start_line,
          end_line: end_line
        }
      end
    end

    chunks
  end

  private

  def detect_language
    ext = File.extname(@file.path)
    LANGUAGE_MAP[ext]
  end

  def parse_ruby
    artifacts = []

    # Extract class definitions
    @content.scan(/^class\s+(\w+)/) do |match|
      line_num = line_number_of("class #{match[0]}")
      end_line = find_end_line(line_num)
      artifacts << { artifact_type: "model", name: match[0], start_line: line_num, end_line: end_line }
    end

    # Extract routes (from config/routes.rb patterns)
    if @file.path.include?("routes")
      @content.scan(/(?:get|post|put|patch|delete|resources?)\s+[:"'](\w+)/) do |match|
        line_num = line_number_of(match[0])
        artifacts << { artifact_type: "route", name: match[0], start_line: line_num, end_line: line_num }
      end
    end

    # Extract controller actions
    if @file.path.include?("controller")
      @content.scan(/def\s+(\w+)/) do |match|
        line_num = line_number_of("def #{match[0]}")
        end_line = find_end_line(line_num)
        artifacts << { artifact_type: "controller", name: match[0], start_line: line_num, end_line: end_line }
      end
    end

    # Extract service objects
    if @file.path.include?("services")
      @content.scan(/class\s+(\w+Service)/) do |match|
        line_num = line_number_of("class #{match[0]}")
        end_line = find_end_line(line_num)
        artifacts << { artifact_type: "service", name: match[0], start_line: line_num, end_line: end_line }
      end
    end

    artifacts
  end

  def parse_javascript
    artifacts = []

    # Extract API client calls (fetch/axios patterns)
    @content.scan(/(?:fetch|axios\.(?:get|post|put|delete))\s*\(\s*[`'"](.*?)[`'"]/) do |match|
      line_num = line_number_of(match[0])
      artifacts << { artifact_type: "api_client", name: match[0], start_line: line_num, end_line: line_num }
    end

    # Extract event emitters
    @content.scan(/\.(?:emit|publish|dispatch)\s*\(\s*['"](.*?)['"]/) do |match|
      line_num = line_number_of(match[0])
      artifacts << { artifact_type: "event_emitter", name: match[0], start_line: line_num, end_line: line_num }
    end

    artifacts
  end

  def parse_yaml
    artifacts = []

    # Docker compose service detection
    if @file.path.include?("docker-compose") || @file.path.include?("compose")
      @content.scan(/^\s{2}(\w[\w-]*):\s*$/) do |match|
        line_num = line_number_of(match[0])
        artifacts << { artifact_type: "service", name: match[0], start_line: line_num, end_line: line_num }
      end
    end

    artifacts
  end

  def line_number_of(text)
    @content.lines.each_with_index do |line, i|
      return i + 1 if line.include?(text)
    end
    1
  end

  def find_end_line(start_line)
    lines = @content.lines
    indent = lines[start_line - 1]&.match(/^(\s*)/)&.captures&.first&.length || 0

    (start_line..lines.length).each do |i|
      line = lines[i - 1]
      next if line.strip.empty?
      if i > start_line && line.match?(/^\s{0,#{indent}}end\b/)
        return i
      end
    end

    [start_line + 50, lines.length].min
  end
end
