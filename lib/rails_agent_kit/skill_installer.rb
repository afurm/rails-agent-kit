# frozen_string_literal: true

require "fileutils"

module RailsAgentKit
  # Copies the agent skills bundled with the gem (skills/<name>/SKILL.md) into a Rails app,
  # e.g. <root>/.cursor/skills/<name>/SKILL.md for Cursor.
  class SkillInstaller
    SKILLS_DIR = File.expand_path("../../skills", __dir__)
    TARGETS = {
      "cursor" => ".cursor/skills",
      "claude" => ".claude/skills"
    }.freeze

    Result = Struct.new(:skill, :path, :status, keyword_init: true)

    def self.available_skills
      Dir.glob(File.join(SKILLS_DIR, "*", "SKILL.md")).map { |f| File.basename(File.dirname(f)) }.sort
    end

    def initialize(root, agent: "cursor", force: false)
      @root = File.expand_path(root)
      @agent = agent.to_s
      @force = force
      raise Error, "unknown agent #{@agent.inspect} (supported: #{TARGETS.keys.join(', ')})" unless TARGETS.key?(@agent)
    end

    # Installs the named skills (default: all bundled skills). Existing files that differ are left
    # untouched unless force: true. Returns one Result per skill with status :created, :updated,
    # :unchanged or :skipped.
    def install(skills = self.class.available_skills)
      each_skill(skills) { |name, source| install_one(name, source) }
    end

    # Same statuses as #install, without writing anything.
    def plan(skills = self.class.available_skills)
      each_skill(skills) { |name, source| install_one(name, source, write: false) }
    end

    private

    def each_skill(skills)
      skills.map do |name|
        source = File.join(SKILLS_DIR, name, "SKILL.md")
        raise Error, "unknown skill #{name.inspect} (available: #{self.class.available_skills.join(', ')})" unless File.file?(source)

        yield name, source
      end
    end

    def install_one(name, source, write: true)
      dest = File.join(@root, TARGETS.fetch(@agent), name, "SKILL.md")
      content = File.read(source)
      status =
        if !File.exist?(dest) then :created
        elsif File.read(dest) == content then :unchanged
        elsif @force then :updated
        else :skipped
        end

      if write && %i[created updated].include?(status)
        FileUtils.mkdir_p(File.dirname(dest))
        File.write(dest, content)
      end
      Result.new(skill: name, path: dest, status: status)
    end
  end
end
