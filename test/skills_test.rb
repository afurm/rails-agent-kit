# frozen_string_literal: true

require "test_helper"
require "yaml"

# Validates the bundled agent skills against the Agent Skills / Cursor SKILL.md format.
class SkillsTest < Minitest::Test
  SKILLS_DIR = RailsAgentKit::SkillInstaller::SKILLS_DIR

  def skill_files
    Dir.glob(File.join(SKILLS_DIR, "*", "SKILL.md"))
  end

  def parse(file)
    text = File.read(file)
    match = text.match(/\A---\n(.*?)\n---\n(.*)\z/m)
    assert match, "#{file} must start with YAML frontmatter delimited by ---"
    [YAML.safe_load(match[1]), match[2]]
  end

  def test_ships_the_rails_8_cursor_skill
    assert_includes RailsAgentKit::SkillInstaller.available_skills, "rails-8-conventions"
  end

  def test_frontmatter_is_valid
    refute_empty skill_files
    skill_files.each do |file|
      meta, body = parse(file)
      folder = File.basename(File.dirname(file))
      assert_equal folder, meta["name"], "#{file}: name must match its folder"
      assert_match(/\A[a-z0-9]+(-[a-z0-9]+)*\z/, meta["name"], "#{file}: name must be lowercase-hyphenated")
      assert_kind_of String, meta["description"]
      assert_operator meta["description"].length, :<=, 1024, "#{file}: description too long"
      assert_match(/\bUse when\b/, meta["description"], "#{file}: description should say when to use it")
      if meta.key?("paths")
        assert_kind_of Array, meta["paths"]
        meta["paths"].each { |glob| assert_kind_of String, glob }
      end
      refute_empty body.strip
    end
  end

  def test_rails_skill_references_the_mcp_tools_the_server_exposes
    _meta, body = parse(File.join(SKILLS_DIR, "rails-8-conventions", "SKILL.md"))
    tool_names = body.scan(/`(rails_[a-z_]+)`/).flatten.uniq
    assert_includes tool_names, "rails_schema"
    assert_includes tool_names, "rails_routes"

    source = File.read(File.expand_path("../lib/rails_agent_kit/server.rb", __dir__))
    exposed = source.scan(/tool_name\s+"([a-z_]+)"/).flatten
    tool_names.each do |name|
      assert_includes exposed, name, "skill references #{name}, which the MCP server does not expose"
    end
  end

  def test_gemspec_packages_the_skills
    spec = Gem::Specification.load(File.expand_path("../rails-agent-kit.gemspec", __dir__))
    assert_includes spec.files, "skills/rails-8-conventions/SKILL.md"
    assert_includes spec.files, "CHANGELOG.md"
    assert spec.metadata["changelog_uri"], "gemspec needs changelog_uri"
  end
end
