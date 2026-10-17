# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "open3"

# End-to-end: spawn exe/rails-agent-kit and talk MCP JSON-RPC over stdio.
class ServerTest < Minitest::Test
  include FixtureHelpers

  EXE = File.expand_path("../exe/rails-agent-kit", __dir__)

  def rpc(root, *requests)
    input = requests.map { |r| JSON.generate(r) }.join("\n") + "\n"
    out, err, status = Open3.capture3(RbConfig.ruby, EXE, "--root", root, stdin_data: input)
    assert status.success?, "server exited with #{status.exitstatus}: #{err}"
    out.lines.map { |l| JSON.parse(l) }
  end

  def init
    { jsonrpc: "2.0", id: 0, method: "initialize",
      params: { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "test", version: "0" } } }
  end

  def initialized
    { jsonrpc: "2.0", method: "notifications/initialized" }
  end

  def call_tool(id, name, args = {})
    { jsonrpc: "2.0", id: id, method: "tools/call", params: { name: name, arguments: args } }
  end

  def test_initialize_and_list_tools
    responses = rpc(fixture_path("blog_app"), init, initialized, { jsonrpc: "2.0", id: 1, method: "tools/list" })
    by_id = responses.to_h { |r| [r["id"], r] }

    assert_equal "rails-agent-kit", by_id[0].dig("result", "serverInfo", "name")
    tools = by_id[1].dig("result", "tools")
    assert_equal %w[rails_routes rails_schema], tools.map { |t| t["name"] }.sort
    schema_tool = tools.find { |t| t["name"] == "rails_schema" }
    assert_equal "string", schema_tool.dig("inputSchema", "properties", "table", "type")
  end

  def test_tool_calls
    responses = rpc(fixture_path("blog_app"), init, initialized,
                    call_tool(1, "rails_schema", { table: "users" }),
                    call_tool(2, "rails_routes", { filter: "health" }),
                    call_tool(3, "rails_schema", { table: "missing" }))
    by_id = responses.to_h { |r| [r["id"], r] }

    schema = JSON.parse(by_id[1].dig("result", "content", 0, "text"))
    assert_equal ["users"], schema["tables"].map { |t| t["name"] }
    assert_includes schema["tables"][0]["columns"].map { |c| c["name"] }, "email"
    assert_equal false, by_id[1].dig("result", "isError")

    routes = JSON.parse(by_id[2].dig("result", "content", 0, "text"))
    assert_equal ["/up(.:format)"], routes["routes"].map { |r| r["path"] }

    assert_equal true, by_id[3].dig("result", "isError")
  end

  def test_routes_fallback_over_mcp
    responses = rpc(fixture_path("sql_app"), init, initialized, call_tool(1, "rails_routes"))
    data = JSON.parse(responses.find { |r| r["id"] == 1 }.dig("result", "content", 0, "text"))
    assert data["routes_unavailable"]
    assert_includes data["routes_rb"], "resources :accounts"
  end

  def test_cli_version_and_bad_root
    out, _err, status = Open3.capture3(RbConfig.ruby, EXE, "--version")
    assert status.success?
    assert_equal RailsAgentKit::VERSION, out.strip

    _out, err, status = Open3.capture3(RbConfig.ruby, EXE, "--root", "/definitely/not/here")
    assert_equal 66, status.exitstatus
    assert_match(/not a directory/, err)
  end
end
