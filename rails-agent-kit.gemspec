# frozen_string_literal: true

require_relative "lib/rails_agent_kit/version"

Gem::Specification.new do |spec|
  spec.name = "rails-agent-kit"
  spec.version = RailsAgentKit::VERSION
  spec.authors = ["Andrii Furmanets"]
  spec.summary = "MCP server and agent skills that give coding agents ground truth about a Rails app's schema and routes."
  spec.description = "rails-agent-kit is a small Model Context Protocol (stdio) server. It exposes a Rails app's " \
                     "database schema (parsed from db/schema.rb without booting the app) and its routes to " \
                     "coding agents such as Cursor and Claude Code, and ships a Rails 8 conventions skill for Cursor/Claude " \
                     "(installed with `rails-agent-kit install-skills`)."
  spec.homepage = "https://github.com/afurm/rails-agent-kit"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "skills/**/SKILL.md", "exe/*", "README.md", "CHANGELOG.md", "LICENSE"]
  spec.bindir = "exe"
  spec.executables = ["rails-agent-kit"]
  spec.require_paths = ["lib"]

  spec.add_dependency "mcp", "~> 1.8"
end
