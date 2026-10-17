# frozen_string_literal: true

require "json"
require "mcp"

module RailsAgentKit
  # Builds the MCP server (official `mcp` Ruby SDK) exposing the app's schema and routes.
  module Server
    module_function

    def build(root:, routes_file: nil)
      context = { root: File.expand_path(root), routes_file: routes_file }
      MCP::Server.new(
        name: "rails-agent-kit",
        version: RailsAgentKit::VERSION,
        instructions: "Ground truth about the Rails app at #{context[:root]}: use rails_schema for tables/columns/indexes " \
                      "and rails_routes for HTTP routes before guessing model attributes or URL helpers.",
        tools: [Tools::RailsSchema, Tools::RailsRoutes],
        server_context: context
      )
    end

    def run_stdio(root:, routes_file: nil)
      server = build(root: root, routes_file: routes_file)
      MCP::Server::Transports::StdioTransport.new(server).open
    end
  end

  module Tools
    # Shared helpers for tool classes.
    module Helpers
      def context_value(server_context, key)
        server_context.respond_to?(:[]) ? server_context[key] : nil
      end

      def json_response(data, error: false)
        MCP::Tool::Response.new([{ type: "text", text: JSON.pretty_generate(data) }], error: error)
      end
    end

    class RailsSchema < MCP::Tool
      extend Helpers

      tool_name "rails_schema"
      description "Database schema of the Rails app (tables, columns with types/null/default, indexes, foreign keys), " \
                  "parsed from db/schema.rb (or db/structure.sql) without booting the app."
      input_schema(
        properties: {
          table: { type: "string", description: "Only return this table (exact name). Omit for all tables." }
        }
      )
      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      def self.call(server_context:, table: nil)
        root = context_value(server_context, :root) || Dir.pwd
        result = SchemaInspector.new(root).call(table: table)
        json_response(result, error: result.key?(:error))
      end
    end

    class RailsRoutes < MCP::Tool
      extend Helpers

      tool_name "rails_routes"
      description "HTTP routes of the Rails app (verb, path, controller#action, route name). Runs " \
                  "`bin/rails routes --expanded` (boots the app); if that fails it explains why and returns config/routes.rb."
      input_schema(
        properties: {
          filter: { type: "string", description: "Case-insensitive substring matched against name, path, verb and controller#action." }
        }
      )
      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      def self.call(server_context:, filter: nil)
        root = context_value(server_context, :root) || Dir.pwd
        routes_file = context_value(server_context, :routes_file)
        json_response(RoutesInspector.new(root, routes_file: routes_file).call(filter: filter))
      end
    end
  end
end
