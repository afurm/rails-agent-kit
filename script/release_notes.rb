#!/usr/bin/env ruby
# frozen_string_literal: true

# Prints GitHub release notes for one version, taken from its CHANGELOG.md section.
#
#   ruby script/release_notes.rb 0.2.0 > notes.md
#
# Used by .github/workflows/release.yml. Exits non-zero if the section is missing or empty.
module ReleaseNotes
  GEM = "rails-agent-kit"

  class MissingSection < StandardError; end

  module_function

  def extract(changelog, version)
    version = version.to_s.delete_prefix("v")
    lines = changelog.lines
    start = lines.index { |l| l.match?(/\A## \[#{Regexp.escape(version)}\]/) }
    raise MissingSection, "CHANGELOG.md has no \"## [#{version}]\" section" unless start

    finish = lines[(start + 1)..].index { |l| l.start_with?("## [") || l.match?(/\A\[[^\]]+\]:\s/) }
    body = lines[(start + 1)...(finish ? start + 1 + finish : lines.size)].join.strip
    raise MissingSection, "The CHANGELOG.md section for #{version} is empty" if body.empty?

    compare = changelog[/^\[#{Regexp.escape(version)}\]:\s*(\S+)/, 1]
    render(version, body, compare)
  end

  def render(version, body, compare)
    out = +"#{body}\n\n"
    out << "## Install\n\n"
    out << "```sh\ngem install #{GEM} -v #{version}\n```\n\n"
    out << "Or in your Gemfile: `gem \"#{GEM}\", \"~> #{version}\", group: :development`.\n\n"
    out << "RubyGems: https://rubygems.org/gems/#{GEM}/versions/#{version}\n"
    out << "Full changelog: #{compare}\n" if compare && !compare.end_with?("/releases/tag/v#{version}")
    out
  end
end

if $PROGRAM_NAME == __FILE__
  abort "usage: ruby script/release_notes.rb VERSION" if ARGV.empty?
  begin
    path = File.expand_path("../CHANGELOG.md", __dir__)
    puts ReleaseNotes.extract(File.read(path), ARGV.first)
  rescue ReleaseNotes::MissingSection => e
    abort "release_notes: #{e.message}"
  end
end
