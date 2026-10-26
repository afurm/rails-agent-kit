# frozen_string_literal: true

require_relative "rails_agent_kit/version"
require_relative "rails_agent_kit/schema_parser"
require_relative "rails_agent_kit/structure_sql_parser"
require_relative "rails_agent_kit/schema_inspector"
require_relative "rails_agent_kit/routes_parser"
require_relative "rails_agent_kit/ruby_env"
require_relative "rails_agent_kit/routes_inspector"
require_relative "rails_agent_kit/project_info"
require_relative "rails_agent_kit/skill_installer"
require_relative "rails_agent_kit/client_config"

# Gives coding agents ground truth about a Rails app (stack, schema, routes) over MCP.
module RailsAgentKit
  class Error < StandardError; end

  # The MCP server is loaded lazily so the parsers can be used without the `mcp` gem.
  def self.server(root: Dir.pwd)
    require_relative "rails_agent_kit/server"
    Server.build(root: root)
  end
end
