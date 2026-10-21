# frozen_string_literal: true

require "fileutils"
require "json"

module RailsAgentKit
  # Writes the project-level MCP configuration that starts rails-agent-kit for each supported client.
  #
  #   cursor  -> .cursor/mcp.json   ("mcpServers", paths relative to ${workspaceFolder})
  #   claude  -> .mcp.json          ("mcpServers", started from the project root)
  #   vscode  -> .vscode/mcp.json   ("servers", paths relative to ${workspaceFolder})
  #   codex   -> ~/.codex/config.toml is a global file, so its snippet is returned, never written
  #
  # Existing files keep every other server. An existing rails-agent-kit entry that differs from the generated
  # one is left alone unless force: true.
  class ClientConfig
    SERVER_NAME = "rails-agent-kit"
    AGENTS = %w[cursor claude vscode codex].freeze
    FILES = {
      "cursor" => [".cursor/mcp.json", "mcpServers"],
      "claude" => [".mcp.json", "mcpServers"],
      "vscode" => [".vscode/mcp.json", "servers"]
    }.freeze

    Result = Struct.new(:agent, :path, :status, :snippet, :message, keyword_init: true)

    # Parses "cursor,claude" or "all" into a list of agents. Raises Error for unknown names.
    def self.parse_agents(value)
      names = value.to_s.split(",").map { |a| a.strip.downcase }.reject(&:empty?)
      return AGENTS.dup if names.empty? || names.include?("all")

      unknown = names - AGENTS
      raise Error, "unknown agent #{unknown.first.inspect} (supported: #{AGENTS.join(', ')}, all)" if unknown.any?

      names.uniq
    end

    attr_reader :root

    def initialize(root, force: false, dry_run: false, bundled: nil)
      @root = File.expand_path(root)
      @force = force
      @dry_run = dry_run
      @bundled = bundled.nil? ? self.class.bundled?(@root) : bundled
    end

    # True when the app's Gemfile (or Gemfile.lock) includes rails-agent-kit, so the server must run through
    # `bundle exec`. Otherwise the globally installed executable is used.
    def self.bundled?(root)
      lock = File.join(root, "Gemfile.lock")
      return File.read(lock).match?(/^ {4}rails-agent-kit \(/) if File.file?(lock)

      gemfile = File.join(root, "Gemfile")
      File.file?(gemfile) && File.read(gemfile).match?(/^\s*gem\s+["']rails-agent-kit["']/)
    end

    def bundled?
      @bundled
    end

    def write(agents)
      agents.map { |agent| agent == "codex" ? codex_result : write_json(agent) }
    end

    # The server entry for one client, as a Hash ready to be stored under the client's servers key.
    def entry_for(agent)
      case agent
      when "cursor", "vscode"
        folder = "${workspaceFolder}"
        entry = agent == "vscode" ? { "type" => "stdio" } : {}
        entry.merge(command_for(folder, env: { "BUNDLE_GEMFILE" => "#{folder}/Gemfile" }))
      when "claude"
        # Claude Code starts project servers from the project root, so a relative root works for the whole team.
        command_for(".")
      else
        raise Error, "no JSON config for #{agent.inspect}"
      end
    end

    def codex_snippet
      args = bundled? ? ["exec", SERVER_NAME, "--root", root] : ["--root", root]
      lines = ["[mcp_servers.#{SERVER_NAME}]", "command = #{toml(bundled? ? 'bundle' : SERVER_NAME)}",
               "args = [#{args.map { |a| toml(a) }.join(', ')}]"]
      lines << "env = { BUNDLE_GEMFILE = #{toml(File.join(root, 'Gemfile'))} }" if bundled?
      "#{lines.join("\n")}\n"
    end

    private

    def command_for(app_root, env: {})
      return { "command" => SERVER_NAME, "args" => ["--root", app_root] } unless bundled?

      entry = { "command" => "bundle", "args" => ["exec", SERVER_NAME, "--root", app_root] }
      entry["env"] = env unless env.empty?
      entry
    end

    def write_json(agent)
      relative, key = FILES.fetch(agent)
      path = File.join(root, relative)
      entry = entry_for(agent)
      config = read_json(path)
      return Result.new(agent: agent, path: path, status: :error, message: config) if config.is_a?(String)

      servers = config[key] ||= {}
      unless servers.is_a?(Hash)
        return Result.new(agent: agent, path: path, status: :error, message: "#{key.inspect} is not an object")
      end

      status =
        if !File.exist?(path) then :created
        elsif !servers.key?(SERVER_NAME) then :added
        elsif servers[SERVER_NAME] == entry then :unchanged
        elsif @force then :updated
        else :skipped
        end

      if %i[created added updated].include?(status) && !@dry_run
        servers[SERVER_NAME] = entry
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, "#{JSON.pretty_generate(config)}\n")
      end
      Result.new(agent: agent, path: path, status: status)
    end

    # Returns the parsed object, {} for a missing or empty file, or an error message String.
    def read_json(path)
      return {} unless File.exist?(path)

      text = File.read(path)
      return {} if text.strip.empty?

      parsed = JSON.parse(text)
      parsed.is_a?(Hash) ? parsed : "not a JSON object"
    rescue JSON::ParserError => e
      "invalid JSON (#{e.message.lines.first.to_s.strip}); fix or remove the file and run init again"
    end

    def codex_result
      Result.new(agent: "codex", path: File.join("~", ".codex", "config.toml"), status: :print, snippet: codex_snippet)
    end

    def toml(value)
      JSON.generate(value.to_s)
    end
  end
end
