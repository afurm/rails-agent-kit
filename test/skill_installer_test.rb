# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "open3"

class SkillInstallerTest < Minitest::Test
  SOURCE = File.join(RailsAgentKit::SkillInstaller::SKILLS_DIR, "rails-8-conventions", "SKILL.md")

  def test_installs_cursor_skill_into_app
    Dir.mktmpdir do |root|
      results = RailsAgentKit::SkillInstaller.new(root).install
      dest = File.join(root, ".cursor/skills/rails-8-conventions/SKILL.md")
      assert_equal [:created], results.map(&:status)
      assert_equal dest, results.first.path
      assert_equal File.read(SOURCE), File.read(dest)
    end
  end

  def test_installs_for_claude
    Dir.mktmpdir do |root|
      RailsAgentKit::SkillInstaller.new(root, agent: "claude").install(["rails-8-conventions"])
      assert File.file?(File.join(root, ".claude/skills/rails-8-conventions/SKILL.md"))
    end
  end

  def test_is_idempotent_and_does_not_clobber_local_edits
    Dir.mktmpdir do |root|
      installer = RailsAgentKit::SkillInstaller.new(root)
      installer.install
      assert_equal [:unchanged], installer.install.map(&:status)

      dest = File.join(root, ".cursor/skills/rails-8-conventions/SKILL.md")
      File.write(dest, "local edits")
      assert_equal [:skipped], installer.install.map(&:status)
      assert_equal "local edits", File.read(dest)

      assert_equal [:updated], RailsAgentKit::SkillInstaller.new(root, force: true).install.map(&:status)
      assert_equal File.read(SOURCE), File.read(dest)
    end
  end

  def test_rejects_unknown_agent_and_skill
    Dir.mktmpdir do |root|
      assert_raises(RailsAgentKit::Error) { RailsAgentKit::SkillInstaller.new(root, agent: "vim") }
      assert_raises(RailsAgentKit::Error) { RailsAgentKit::SkillInstaller.new(root).install(["nope"]) }
    end
  end
end

class InstallSkillsCliTest < Minitest::Test
  EXE = File.expand_path("../exe/rails-agent-kit", __dir__)

  def run_cli(*args)
    require "open3"
    Open3.capture3(RbConfig.ruby, EXE, *args)
  end

  def test_install_skills_command
    Dir.mktmpdir do |root|
      out, err, status = run_cli("install-skills", "--root", root)
      assert status.success?, err
      assert_match(%r{created\s+.*\.cursor/skills/rails-8-conventions/SKILL\.md}, out)

      out, _err, status = run_cli("install-skills", "--root", root)
      assert status.success?
      assert_match(/unchanged/, out)
    end
  end

  def test_install_skills_rejects_unknown_agent
    Dir.mktmpdir do |root|
      _out, err, status = run_cli("install-skills", "--root", root, "--agent", "vim")
      assert_equal 64, status.exitstatus
      assert_match(/unknown agent/, err)
    end
  end
end

class SkillInstallerPlanTest < Minitest::Test
  def test_plan_reports_statuses_without_writing
    Dir.mktmpdir do |root|
      assert_equal [:created], RailsAgentKit::SkillInstaller.new(root).plan.map(&:status)
      assert_empty Dir.children(root)
    end
  end
end

class InstructionFileInstallerTest < Minitest::Test
  START = RailsAgentKit::SkillInstaller::MARKER_START
  FINISH = RailsAgentKit::SkillInstaller::MARKER_END

  def installer(root, agent = "codex")
    RailsAgentKit::SkillInstaller.new(root, agent: agent)
  end

  def test_creates_agents_md_from_the_skill_source
    Dir.mktmpdir do |root|
      results = installer(root).install
      path = File.join(root, "AGENTS.md")
      assert_equal [:created], results.map(&:status)
      assert_equal path, results.first.path

      content = File.read(path)
      assert content.start_with?(START)
      assert content.end_with?("#{FINISH}\n")
      refute_match(/^name: rails-8-conventions/, content, "front matter is stripped")
      assert_includes content, "## Rails 8 conventions"
      assert_includes content, "### 1. Check the facts before you edit"
      assert_includes content, "rails_schema"
    end
  end

  def test_appends_to_an_existing_file_without_markers
    Dir.mktmpdir do |root|
      path = File.join(root, "AGENTS.md")
      File.write(path, "# My app\n\nUse pnpm.\n")
      assert_equal [:added], installer(root).install.map(&:status)

      content = File.read(path)
      assert content.start_with?("# My app\n\nUse pnpm.\n\n#{START}")
      assert_equal 1, content.scan(START).size
      assert_equal [:unchanged], installer(root).install.map(&:status)
    end
  end

  def test_replaces_only_the_managed_block
    Dir.mktmpdir do |root|
      path = File.join(root, "AGENTS.md")
      File.write(path, "# Top\n\n#{START}\nold rules\n#{FINISH}\n\n## Bottom\n\nKeep me.\n")
      assert_equal [:updated], installer(root).install.map(&:status)

      content = File.read(path)
      assert content.start_with?("# Top\n\n#{START}")
      assert content.end_with?("#{FINISH}\n\n## Bottom\n\nKeep me.\n")
      refute_includes content, "old rules"
      assert_equal [:unchanged], installer(root).install.map(&:status)
    end
  end

  def test_skips_a_file_with_an_unmatched_marker
    Dir.mktmpdir do |root|
      path = File.join(root, "GEMINI.md")
      File.write(path, "#{START}\nhalf a block\n")
      result = installer(root, "gemini").install.first
      assert_equal :skipped, result.status
      assert_match(/unmatched/, result.message)
      assert_equal "#{START}\nhalf a block\n", File.read(path)
    end
  end

  def test_copilot_and_gemini_targets
    Dir.mktmpdir do |root|
      installer(root, "copilot").install
      installer(root, "gemini").install
      assert_includes File.read(File.join(root, ".github/copilot-instructions.md")), START
      assert_includes File.read(File.join(root, "GEMINI.md")), START
    end
  end

  def test_plan_does_not_write
    Dir.mktmpdir do |root|
      assert_equal [:created], installer(root).plan.map(&:status)
      assert_empty Dir.children(root)
    end
  end

  def test_headings_inside_code_fences_are_not_demoted
    text = "# Title\n\n```sh\n# a shell comment\n```\n"
    assert_equal "## Title\n\n```sh\n# a shell comment\n```\n", RailsAgentKit::SkillInstaller.demote_headings(text)
  end

  def test_cli_writes_agents_md
    Dir.mktmpdir do |root|
      out, err, status = Open3.capture3(RbConfig.ruby, InstallSkillsCliTest::EXE, "install-skills", "--root", root, "--agent", "codex")
      assert status.success?, err
      assert_match(/created\s+.*AGENTS\.md/, out)
    end
  end
end
