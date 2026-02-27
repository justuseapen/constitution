module Importers
  class JiraImporter
    JIRA_STATUS_MAP = {
      "To Do" => :todo,
      "In Progress" => :in_progress,
      "In Review" => :review,
      "Done" => :done,
      "Backlog" => :backlog
    }.freeze

    JIRA_PRIORITY_MAP = {
      "Highest" => :critical,
      "High" => :high,
      "Medium" => :medium,
      "Low" => :low,
      "Lowest" => :low
    }.freeze

    def initialize(project:, user:, jira_url:, jira_email:, jira_token:, jira_project_key:)
      @project = project
      @user = user
      @jira_url = jira_url.chomp("/")
      @jira_email = jira_email
      @jira_token = jira_token
      @jira_project_key = jira_project_key
    end

    def import!
      issues = fetch_all_issues
      phase_map = create_phases(issues)
      create_work_orders(issues, phase_map)
    end

    private

    def fetch_all_issues
      all_issues = []
      start_at = 0
      max_results = 50

      loop do
        response = jira_request(
          "/rest/api/3/search",
          params: {
            jql: "project=#{@jira_project_key} ORDER BY created ASC",
            startAt: start_at,
            maxResults: max_results,
            fields: "summary,description,status,priority,issuetype,parent,assignee,created,updated"
          }
        )

        issues = response["issues"] || []
        all_issues.concat(issues)
        break if all_issues.length >= response["total"].to_i || issues.empty?
        start_at += max_results
      end

      all_issues
    end

    def create_phases(issues)
      phase_map = {}
      epics = issues.select { |i| i.dig("fields", "issuetype", "name") == "Epic" }

      epics.each_with_index do |epic, index|
        phase = @project.phases.find_or_create_by!(name: epic.dig("fields", "summary")) do |p|
          p.position = index
        end
        phase_map[epic["key"]] = phase
      end

      # Create default phase for orphan issues
      unless phase_map.any?
        default_phase = @project.phases.find_or_create_by!(name: "Imported from Jira") do |p|
          p.position = 0
        end
        phase_map["_default"] = default_phase
      end

      phase_map
    end

    def create_work_orders(issues, phase_map)
      issues.reject { |i| i.dig("fields", "issuetype", "name") == "Epic" }.each do |issue|
        fields = issue["fields"]
        parent_key = fields.dig("parent", "key")
        phase = phase_map[parent_key] || phase_map["_default"] || phase_map.values.first

        jira_status = fields.dig("status", "name") || "Backlog"
        jira_priority = fields.dig("priority", "name") || "Medium"

        @project.work_orders.find_or_create_by!(title: fields["summary"]) do |wo|
          wo.description = extract_description(fields["description"])
          wo.status = map_status(jira_status)
          wo.priority = map_priority(jira_priority)
          wo.phase = phase
          wo.metadata = { jira_key: issue["key"], jira_url: "#{@jira_url}/browse/#{issue["key"]}" }
        end
      end
    end

    def extract_description(adf_content)
      return "" unless adf_content.is_a?(Hash)
      extract_text_from_adf(adf_content)
    end

    def extract_text_from_adf(node)
      return node["text"] || "" if node["type"] == "text"
      return "" unless node["content"].is_a?(Array)
      node["content"].map { |child| extract_text_from_adf(child) }.join("\n")
    end

    def map_status(jira_status)
      JIRA_STATUS_MAP.find { |pattern, _| jira_status.downcase.include?(pattern.downcase) }&.last || :backlog
    end

    def map_priority(jira_priority)
      JIRA_PRIORITY_MAP[jira_priority] || :medium
    end

    def jira_request(path, params: {})
      uri = URI("#{@jira_url}#{path}")
      uri.query = URI.encode_www_form(params) if params.any?

      request = Net::HTTP::Get.new(uri)
      request.basic_auth(@jira_email, @jira_token)
      request["Accept"] = "application/json"

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end

      raise "Jira API error: #{response.code} #{response.body}" unless response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    end
  end
end
