#!/usr/bin/env ruby
# frozen_string_literal: true

# Prints the GitHub release notes for one version, built from its CHANGELOG.md section.
#
#   ruby script/release_notes.rb 0.2.0 > notes.md
#
# A version section looks like this (every part except one change list is optional):
#
#   ## [0.2.0] - 2026-10-30
#
#   One or two sentences on what the release brings. This becomes the lead paragraph.
#
#   ### Upgrading
#   What existing users need to do, if anything.
#
#   ### Added / ### Changed / ### Deprecated / ### Removed / ### Fixed / ### Security
#   - **Outcome in bold.** Details. By @user. (#12)
#
#   ### Known limitations
#   ### Thanks
#
# Keep a Changelog headings become release-note sections (Added -> New), and the notes get an install
# snippet and a full-changelog link. Used by .github/workflows/release.yml. Exits non-zero if the
# section is missing or empty.
module ReleaseNotes
  GEM = "rails-agent-kit"

  SECTIONS = {
    "Added" => "New",
    "Changed" => "Changed",
    "Deprecated" => "Deprecated",
    "Removed" => "Removed",
    "Fixed" => "Fixed",
    "Security" => "Security",
    "Known limitations" => "Known limitations",
    "Thanks" => "Thanks"
  }.freeze

  class MissingSection < StandardError; end

  module_function

  def title(version)
    "#{GEM} #{version.to_s.delete_prefix("v")}"
  end

  def extract(changelog, version)
    version = version.to_s.delete_prefix("v")
    lines = changelog.lines
    start = lines.index { |l| l.match?(/\A## \[#{Regexp.escape(version)}\]/) }
    raise MissingSection, "CHANGELOG.md has no \"## [#{version}]\" section" unless start

    finish = lines[(start + 1)..].index { |l| l.start_with?("## [") || l.match?(/\A\[[^\]]+\]:\s/) }
    body = lines[(start + 1)...(finish ? start + 1 + finish : lines.size)].join.strip
    raise MissingSection, "The CHANGELOG.md section for #{version} is empty" if body.empty?

    compare = changelog[/^\[#{Regexp.escape(version)}\]:\s*(\S+)/, 1]
    render(version, parse(body), compare)
  end

  # Splits a section body into its lead text and its "### Heading" subsections, in order.
  def parse(body)
    lead = +""
    sections = []
    body.each_line do |line|
      if (heading = line[/\A### (.+)/, 1])
        sections << [heading.strip, +""]
      elsif sections.empty?
        lead << line
      else
        sections.last[1] << line
      end
    end
    {
      lead: unwrap(lead.strip),
      sections: sections.map { |h, text| [h, unwrap(text.strip)] }.reject { |_, text| text.empty? }
    }
  end

  BLOCK_START = /\A\s*(?:[-*+]\s|\d+\.\s|#|\||>|```)/

  # GitHub renders every newline in a release body as a line break, so join the hard-wrapped lines of
  # paragraphs and list items. Code fences, tables, headings and new list items keep their own lines.
  def unwrap(text)
    out = []
    fenced = false
    text.each_line(chomp: true) do |line|
      fence = line.lstrip.start_with?("```")
      if !fenced && !fence && !line.strip.empty? && !line.match?(BLOCK_START) &&
         out.last && !out.last.strip.empty? && !out.last.match?(/\A\s*(?:#|\||```)/)
        out[-1] = "#{out.last} #{line.strip}"
      else
        out << line
      end
      fenced = !fenced if fence
    end
    out.join("\n")
  end

  def render(version, parsed, compare)
    sections = parsed[:sections]
    upgrading = sections.find { |h, _| h == "Upgrading" }&.last

    out = +""
    out << "#{parsed[:lead]}\n\n" unless parsed[:lead].empty?
    out << "```sh\nbundle add #{GEM} --version #{version} --group development\n```\n\n"
    out << "Or `gem install #{GEM} -v #{version}`. RubyGems: https://rubygems.org/gems/#{GEM}/versions/#{version}\n\n"
    out << "#{upgrading}\n\n" if upgrading

    ordered(sections).each do |heading, text|
      out << "## #{SECTIONS.fetch(heading, heading)}\n\n#{text}\n\n"
    end

    out << "**Full changelog**: #{compare}\n" if compare && !compare.end_with?("/releases/tag/v#{version}")
    out.rstrip << "\n"
  end

  # Change lists first (in Keep a Changelog order), then any other headings, then limitations and thanks.
  def ordered(sections)
    rest = sections.reject { |h, _| h == "Upgrading" }
    tail = ["Known limitations", "Thanks"]
    known = SECTIONS.keys - tail
    rest.select { |h, _| known.include?(h) }.sort_by { |h, _| known.index(h) } +
      rest.reject { |h, _| SECTIONS.key?(h) } +
      rest.select { |h, _| tail.include?(h) }.sort_by { |h, _| tail.index(h) }
  end
end

if $PROGRAM_NAME == __FILE__
  abort "usage: ruby script/release_notes.rb [--title] VERSION" if ARGV.empty?
  if ARGV.first == "--title"
    puts ReleaseNotes.title(ARGV.fetch(1))
    exit
  end
  begin
    path = File.expand_path("../CHANGELOG.md", __dir__)
    puts ReleaseNotes.extract(File.read(path), ARGV.first)
  rescue ReleaseNotes::MissingSection => e
    abort "release_notes: #{e.message}"
  end
end
