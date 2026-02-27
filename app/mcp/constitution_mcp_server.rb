require_relative "../../config/environment"

class ConstitutionMcpServer
  PROTOCOL_VERSION = "2024-11-05"

  def initialize
    @tools = load_tools
    @resources = load_resources
  end

  def run
    $stdin.each_line do |line|
      request = JSON.parse(line.strip)
      response = handle_request(request)
      $stdout.puts(response.to_json)
      $stdout.flush
    rescue JSON::ParserError => e
      error_response(-32700, "Parse error: #{e.message}", request&.dig("id"))
    rescue StandardError => e
      error_response(-32603, "Internal error: #{e.message}", request&.dig("id"))
    end
  end

  private

  def handle_request(request)
    method = request["method"]
    id = request["id"]
    params = request["params"] || {}

    case method
    when "initialize"
      initialize_response(id)
    when "tools/list"
      tools_list_response(id)
    when "tools/call"
      tools_call_response(id, params)
    when "resources/list"
      resources_list_response(id)
    when "resources/read"
      resources_read_response(id, params)
    else
      error_response(-32601, "Method not found: #{method}", id)
    end
  end

  def initialize_response(id)
    {
      jsonrpc: "2.0",
      id: id,
      result: {
        protocolVersion: PROTOCOL_VERSION,
        capabilities: {
          tools: { listChanged: false },
          resources: { subscribe: false, listChanged: false }
        },
        serverInfo: { name: "constitution", version: "1.0.0" }
      }
    }
  end

  def tools_list_response(id)
    { jsonrpc: "2.0", id: id, result: { tools: @tools.map(&:definition) } }
  end

  def tools_call_response(id, params)
    tool_name = params["name"]
    arguments = params["arguments"] || {}

    tool = @tools.find { |t| t.name == tool_name }
    return error_response(-32602, "Unknown tool: #{tool_name}", id) unless tool

    result = tool.call(arguments)
    {
      jsonrpc: "2.0",
      id: id,
      result: { content: [{ type: "text", text: result.to_json }] }
    }
  rescue StandardError => e
    { jsonrpc: "2.0", id: id, result: { content: [{ type: "text", text: "Error: #{e.message}" }], isError: true } }
  end

  def resources_list_response(id)
    { jsonrpc: "2.0", id: id, result: { resources: @resources.map(&:definition) } }
  end

  def resources_read_response(id, params)
    uri = params["uri"]
    resource = @resources.find { |r| r.matches?(uri) }
    return error_response(-32602, "Unknown resource: #{uri}", id) unless resource

    content = resource.read(uri)
    { jsonrpc: "2.0", id: id, result: { contents: [{ uri: uri, mimeType: "application/json", text: content.to_json }] } }
  end

  def error_response(code, message, id)
    { jsonrpc: "2.0", id: id, error: { code: code, message: message } }
  end

  def load_tools
    [
      Tools::ListWorkOrders.new,
      Tools::GetWorkOrder.new,
      Tools::UpdateWorkOrderStatus.new,
      Tools::GetRequirements.new,
      Tools::GetBlueprint.new,
      Tools::GetSystemDependencies.new,
      Tools::GetImpactAnalysis.new,
      Tools::Search.new
    ]
  end

  def load_resources
    [
      Resources::ProjectRequirements.new,
      Resources::ProjectBlueprints.new,
      Resources::WorkOrderResource.new,
      Resources::SystemDependenciesResource.new
    ]
  end
end
