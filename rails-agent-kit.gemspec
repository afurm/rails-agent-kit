# frozen_string_literal: true

require_relative "lib/rails_agent_kit/version"

Gem::Specification.new do |spec|
  spec.name = "rails-agent-kit"
  spec.version = RailsAgentKit::VERSION
  spec.authors = ["Andrii Furmanets"]
  spec.summary = "MCP server and Rails 8 agent skill that give coding agents (Cursor, Claude Code, Codex) " \
                 "ground truth about your Rails app's schema and routes."
  spec.description = "rails-agent-kit is a read-only Model Context Protocol (stdio) server for Rails apps. " \
                     "rails_schema returns tables, columns, indexes and foreign keys parsed statically from " \
                     "db/schema.rb (without booting the app); rails_routes returns every route from " \
                     "`bin/rails routes --expanded`. It also ships a Rails 8 conventions skill for Cursor and " \
                     "Claude Code, installed with `rails-agent-kit install-skills`."
  spec.homepage = "https://github.com/afurm/rails-agent-kit"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/main"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "skills/**/SKILL.md", "exe/*", "README.md", "CHANGELOG.md", "LICENSE"]
  spec.bindir = "exe"
  spec.executables = ["rails-agent-kit"]
  spec.require_paths = ["lib"]

  spec.add_dependency "mcp", "~> 1.8"
end
