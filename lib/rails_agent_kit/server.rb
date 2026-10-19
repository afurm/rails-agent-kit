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
        instructions: "Ground truth about the Rails app at #{context[:root]}. Check it before guessing model " \
                      "attributes or URL helpers. rails_schema with no arguments lists every table (column counts " \
                      "and foreign key targets); then pass table: (one name or an array) for columns, indexes " \
                      "and foreign keys, or search: to find a column by name. rails_routes lists HTTP routes; " \
                      "pass filter: to narrow them.",
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
        MCP::Tool::Response.new([{ type: "text", text: JSON.generate(data) }], error: error)
      end
    end

    class RailsSchema < MCP::Tool
      extend Helpers

      tool_name "rails_schema"
      description "Database schema of the Rails app, parsed from db/schema.rb (or db/structure.sql) without booting " \
                  "the app. With no arguments it returns a compact overview: every table with its column count, " \
                  "non-default primary key and foreign key targets. Pass table for full columns (type, null, " \
                  "default, ...), indexes and foreign keys, or search to find tables and columns by name."
      input_schema(
        properties: {
          table: {
            anyOf: [{ type: "string" }, { type: "array", items: { type: "string" } }],
            description: "Table name(s) to return in full: one exact name, an array, or a comma-separated list."
          },
          search: {
            type: "string",
            description: "Case-insensitive substring matched against table and column names, e.g. \"email\"."
          },
          detail: {
            type: "string", enum: SchemaInspector::DETAILS,
            description: "\"overview\" (default with no table/search) or \"full\" (default with table)."
          }
        }
      )
      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      def self.call(server_context:, table: nil, search: nil, detail: nil)
        root = context_value(server_context, :root) || Dir.pwd
        result = SchemaInspector.new(root).call(table: table, search: search, detail: detail)
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
