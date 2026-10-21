# frozen_string_literal: true

require "test_helper"
require "json"
require "open3"
require "tmpdir"

class ClientConfigTest < Minitest::Test
  def config(root, **opts)
    RailsAgentKit::ClientConfig.new(root, **opts)
  end

  def read_json(root, path)
    JSON.parse(File.read(File.join(root, path)))
  end

  def test_parse_agents
    assert_equal %w[cursor claude vscode codex], RailsAgentKit::ClientConfig.parse_agents("all")
    assert_equal %w[cursor claude vscode codex], RailsAgentKit::ClientConfig.parse_agents(nil)
    assert_equal %w[claude cursor], RailsAgentKit::ClientConfig.parse_agents(" Claude, cursor,claude")
    error = assert_raises(RailsAgentKit::Error) { RailsAgentKit::ClientConfig.parse_agents("cursor,vim") }
    assert_match(/unknown agent "vim"/, error.message)
  end

  def test_writes_each_client_format_for_an_installed_gem
    Dir.mktmpdir do |root|
      results = config(root, bundled: false).write(%w[cursor claude vscode codex])
      assert_equal %i[created created created print], results.map(&:status)

      assert_equal({ "mcpServers" => { "rails-agent-kit" => {
                     "command" => "rails-agent-kit", "args" => ["--root", "${workspaceFolder}"]
                   } } }, read_json(root, ".cursor/mcp.json"))
      assert_equal({ "mcpServers" => { "rails-agent-kit" => {
                     "command" => "rails-agent-kit", "args" => ["--root", "."]
                   } } }, read_json(root, ".mcp.json"))
      assert_equal({ "servers" => { "rails-agent-kit" => {
                     "type" => "stdio", "command" => "rails-agent-kit", "args" => ["--root", "${workspaceFolder}"]
                   } } }, read_json(root, ".vscode/mcp.json"))

      codex = results.last.snippet
      assert_includes codex, "[mcp_servers.rails-agent-kit]"
      assert_includes codex, %(command = "rails-agent-kit")
      assert_includes codex, %(args = ["--root", #{JSON.generate(File.expand_path(root))}])
      refute File.exist?(File.join(root, ".codex"))
    end
  end

  def test_uses_bundle_exec_when_the_gemfile_lock_has_the_gem
    Dir.mktmpdir do |root|
      File.write(File.join(root, "Gemfile.lock"), "GEM\n  specs:\n    rails-agent-kit (0.1.0)\n      mcp (~> 1.8)\n")
      cfg = config(root)
      assert cfg.bundled?
      results = cfg.write(%w[cursor claude vscode codex])

      cursor = read_json(root, ".cursor/mcp.json").dig("mcpServers", "rails-agent-kit")
      assert_equal "bundle", cursor["command"]
      assert_equal ["exec", "rails-agent-kit", "--root", "${workspaceFolder}"], cursor["args"]
      assert_equal({ "BUNDLE_GEMFILE" => "${workspaceFolder}/Gemfile" }, cursor["env"])

      claude = read_json(root, ".mcp.json").dig("mcpServers", "rails-agent-kit")
      assert_equal({ "command" => "bundle", "args" => ["exec", "rails-agent-kit", "--root", "."] }, claude)

      vscode = read_json(root, ".vscode/mcp.json").dig("servers", "rails-agent-kit")
      assert_equal "stdio", vscode["type"]
      assert_equal "bundle", vscode["command"]

      codex = results.last.snippet
      assert_includes codex, %(command = "bundle")
      assert_includes codex, "BUNDLE_GEMFILE = #{JSON.generate(File.join(File.expand_path(root), 'Gemfile'))}"
    end
  end

  def test_detects_the_gem_in_a_gemfile_without_a_lock
    Dir.mktmpdir do |root|
      File.write(File.join(root, "Gemfile"), %(source "https://rubygems.org"\ngem "rails"\n  gem 'rails-agent-kit', group: :development\n))
      assert RailsAgentKit::ClientConfig.bundled?(root)
      File.write(File.join(root, "Gemfile"), %(gem "rails"\n# gem "rails-agent-kit"\n))
      refute RailsAgentKit::ClientConfig.bundled?(root)
    end
  end

  def test_merges_into_existing_config_and_keeps_other_servers
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, ".cursor"))
      existing = { "mcpServers" => { "github" => { "url" => "https://example.com/mcp" } }, "other" => true }
      File.write(File.join(root, ".cursor/mcp.json"), JSON.generate(existing))

      assert_equal [:added], config(root, bundled: false).write(["cursor"]).map(&:status)
      merged = read_json(root, ".cursor/mcp.json")
      assert_equal({ "url" => "https://example.com/mcp" }, merged.dig("mcpServers", "github"))
      assert merged["other"]
      assert_equal "rails-agent-kit", merged.dig("mcpServers", "rails-agent-kit", "command")
    end
  end

  def test_second_run_is_unchanged_and_edited_entries_are_kept_unless_forced
    Dir.mktmpdir do |root|
      config(root, bundled: false).write(%w[cursor claude])
      before = File.read(File.join(root, ".mcp.json"))
      assert_equal %i[unchanged unchanged], config(root, bundled: false).write(%w[cursor claude]).map(&:status)
      assert_equal before, File.read(File.join(root, ".mcp.json"))

      edited = read_json(root, ".mcp.json")
      edited["mcpServers"]["rails-agent-kit"]["args"] += ["--routes-file", "tmp/routes.txt"]
      File.write(File.join(root, ".mcp.json"), JSON.generate(edited))
      assert_equal [:skipped], config(root, bundled: false).write(["claude"]).map(&:status)
      assert_includes read_json(root, ".mcp.json").dig("mcpServers", "rails-agent-kit", "args"), "--routes-file"

      assert_equal [:updated], config(root, bundled: false, force: true).write(["claude"]).map(&:status)
      assert_equal ["--root", "."], read_json(root, ".mcp.json").dig("mcpServers", "rails-agent-kit", "args")
    end
  end

  def test_dry_run_writes_nothing
    Dir.mktmpdir do |root|
      results = config(root, bundled: false, dry_run: true).write(%w[cursor claude vscode codex])
      assert_equal %i[created created created print], results.map(&:status)
      assert_empty Dir.children(root)
    end
  end

  def test_invalid_json_is_reported_and_left_untouched
    Dir.mktmpdir do |root|
      File.write(File.join(root, ".mcp.json"), "{ not json")
      result = config(root, bundled: false).write(["claude"]).first
      assert_equal :error, result.status
      assert_match(/invalid JSON/, result.message)
      assert_equal "{ not json", File.read(File.join(root, ".mcp.json"))
    end
  end
end

class InitCliTest < Minitest::Test
  EXE = File.expand_path("../exe/rails-agent-kit", __dir__)

  def run_cli(*args)
    Open3.capture3(RbConfig.ruby, EXE, *args)
  end

  def test_init_writes_configs_installs_skills_and_prints_codex_snippet
    Dir.mktmpdir do |root|
      out, err, status = run_cli("init", "--root", root)
      assert status.success?, err
      assert_match(%r{created\s+\.cursor/mcp\.json}, out)
      assert_match(%r{created\s+\.mcp\.json}, out)
      assert_match(%r{created\s+\.vscode/mcp\.json}, out)
      assert_match(%r{created\s+\.cursor/skills/rails-8-conventions/SKILL\.md}, out)
      assert_match(%r{created\s+\.claude/skills/rails-8-conventions/SKILL\.md}, out)
      assert_includes out, "[mcp_servers.rails-agent-kit]"
      assert File.file?(File.join(root, ".claude/skills/rails-8-conventions/SKILL.md"))

      out, err, status = run_cli("init", "--root", root)
      assert status.success?, err
      refute_match(/^(created|added|updated)/, out)
      assert_equal 5, out.scan(/^unchanged/).size
    end
  end

  def test_init_dry_run_and_agent_list
    Dir.mktmpdir do |root|
      out, err, status = run_cli("init", "--root", root, "--agent", "claude", "--dry-run")
      assert status.success?, err
      assert_match(%r{would create\s+\.mcp\.json}, out)
      assert_match(%r{would create\s+\.claude/skills/}, out)
      refute_match(/cursor|vscode|mcp_servers/, out)
      assert_empty Dir.children(root)
    end
  end

  def test_init_rejects_unknown_agent
    Dir.mktmpdir do |root|
      _out, err, status = run_cli("init", "--root", root, "--agent", "cursor,vim")
      assert_equal 64, status.exitstatus
      assert_match(/unknown agent "vim"/, err)
    end
  end

  def test_init_exits_65_on_unreadable_config
    Dir.mktmpdir do |root|
      File.write(File.join(root, ".mcp.json"), "[1,")
      out, _err, status = run_cli("init", "--root", root, "--agent", "claude", "--no-skills")
      assert_equal 65, status.exitstatus
      assert_match(/error\s+\.mcp\.json \(invalid JSON/, out)
    end
  end
end
