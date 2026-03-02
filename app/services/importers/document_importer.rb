module Importers
  class DocumentImporter
    SUPPORTED_TYPES = %w[
      text/markdown
      text/plain
      application/vnd.openxmlformats-officedocument.wordprocessingml.document
      application/pdf
    ].freeze

    def initialize(project:, user:, file:, document_type: :feature_requirement)
      @project = project
      @user = user
      @file = file
      @document_type = document_type
    end

    def import!
      content = extract_content
      title = extract_title

      document = @project.documents.create!(
        title: title,
        body: content,
        document_type: @document_type,
        created_by: @user
      )

      structure_with_ai(document) if should_structure?(content)
      document
    end

    private

    def extract_content
      case detect_type
      when :markdown
        markdown_to_html(read_file)
      when :plain_text
        "<p>#{ERB::Util.html_escape(read_file).gsub("\n\n", "</p><p>").gsub("\n", "<br>")}</p>"
      when :docx
        extract_docx
      when :pdf
        extract_pdf
      else
        raise "Unsupported file type: #{@file.content_type}"
      end
    end

    def extract_title
      filename = if @file.respond_to?(:original_filename)
        @file.original_filename
      else
        File.basename(@file.path)
      end
      File.basename(filename, File.extname(filename)).titleize
    end

    def detect_type
      content_type = @file.respond_to?(:content_type) ? @file.content_type : nil
      extension = File.extname(extract_title.parameterize).downcase

      if content_type&.include?("markdown") || [ ".md", ".markdown" ].include?(extension)
        :markdown
      elsif content_type&.include?("wordprocessingml") || extension == ".docx"
        :docx
      elsif content_type&.include?("pdf") || extension == ".pdf"
        :pdf
      else
        :plain_text
      end
    end

    def read_file
      if @file.respond_to?(:read)
        @file.read.force_encoding("UTF-8")
      else
        File.read(@file.path, encoding: "UTF-8")
      end
    end

    def markdown_to_html(markdown)
      # Simple markdown to HTML conversion
      html = markdown
        .gsub(/^### (.+)$/, '<h3>\1</h3>')
        .gsub(/^## (.+)$/, '<h2>\1</h2>')
        .gsub(/^# (.+)$/, '<h1>\1</h1>')
        .gsub(/\*\*(.+?)\*\*/, '<strong>\1</strong>')
        .gsub(/\*(.+?)\*/, '<em>\1</em>')
        .gsub(/^- (.+)$/, '<li>\1</li>')
        .gsub(/^(\d+)\. (.+)$/, '<li>\2</li>')
        .gsub(/\n\n/, "</p><p>")

      "<p>#{html}</p>"
    end

    def extract_docx
      if defined?(Docx)
        doc = Docx::Document.open(@file.respond_to?(:tempfile) ? @file.tempfile.path : @file.path)
        paragraphs = doc.paragraphs.map do |p|
          if p.text.strip.empty?
            nil
          else
            "<p>#{ERB::Util.html_escape(p.text)}</p>"
          end
        end.compact
        paragraphs.join("\n")
      else
        "<p>DOCX parsing requires the 'docx' gem. Raw content could not be extracted.</p>"
      end
    end

    def extract_pdf
      if defined?(PDF::Reader)
        reader = PDF::Reader.new(@file.respond_to?(:tempfile) ? @file.tempfile.path : @file.path)
        pages = reader.pages.map do |page|
          "<p>#{ERB::Util.html_escape(page.text).gsub("\n\n", "</p><p>").gsub("\n", "<br>")}</p>"
        end
        pages.join("\n<hr>\n")
      else
        "<p>PDF parsing requires the 'pdf-reader' gem. Raw content could not be extracted.</p>"
      end
    end

    def should_structure?(content)
      defined?(OPENROUTER_CLIENT) && OPENROUTER_CLIENT.present? && content.length > 500
    end

    def structure_with_ai(document)
      response = OPENROUTER_CLIENT.chat(
        parameters: {
          model: "anthropic/claude-haiku-4-5-20251001",
          messages: [ {
            role: "user",
            content: <<~PROMPT
              Take this raw document content and restructure it into a well-organized #{@document_type.to_s.humanize} document.
              Add appropriate HTML headings (h2, h3), organize related content into sections,
              and ensure clarity. Preserve all original information. Return ONLY the HTML content.

              Content:
              #{document.body.truncate(6000)}
            PROMPT
          } ]
        }
      )

      structured_body = response.dig("choices", 0, "message", "content")
      document.update!(body: structured_body) if structured_body.present?
    rescue StandardError => e
      Rails.logger.warn("AI structuring failed for document #{document.id}: #{e.message}")
    end
  end
end
