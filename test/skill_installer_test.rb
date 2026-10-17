# frozen_string_literal: true

require "test_helper"
require "tmpdir"

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
