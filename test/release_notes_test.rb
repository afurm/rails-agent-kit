# frozen_string_literal: true

require_relative "test_helper"
require_relative "../script/release_notes"

class ReleaseNotesTest < Minitest::Test
  CHANGELOG = <<~MD
    # Changelog

    ## [Unreleased]

    ### Added

    - Something not released yet.

    ## [0.2.0] - 2026-10-30

    ### Added

    - Compact `rails_schema` overview.

    ### Fixed

    - A bug.

    ## [0.1.0] - 2026-10-17

    ### Added

    - First release.

    [Unreleased]: https://github.com/afurm/rails-agent-kit/compare/v0.2.0...HEAD
    [0.2.0]: https://github.com/afurm/rails-agent-kit/compare/v0.1.0...v0.2.0
    [0.1.0]: https://github.com/afurm/rails-agent-kit/releases/tag/v0.1.0
  MD

  def test_extracts_the_version_section
    notes = ReleaseNotes.extract(CHANGELOG, "v0.2.0")
    assert notes.start_with?("### Added\n\n- Compact `rails_schema` overview.")
    assert_includes notes, "### Fixed\n\n- A bug."
    refute_includes notes, "First release"
    refute_includes notes, "not released yet"
    assert_includes notes, "gem install rails-agent-kit -v 0.2.0"
    assert_includes notes, "https://rubygems.org/gems/rails-agent-kit/versions/0.2.0"
    assert_includes notes, "Full changelog: https://github.com/afurm/rails-agent-kit/compare/v0.1.0...v0.2.0"
  end

  def test_last_section_stops_at_the_link_references
    notes = ReleaseNotes.extract(CHANGELOG, "0.1.0")
    assert notes.start_with?("### Added\n\n- First release.")
    refute_includes notes, "[Unreleased]:"
    refute_includes notes, "Full changelog"
  end

  def test_missing_version
    error = assert_raises(ReleaseNotes::MissingSection) { ReleaseNotes.extract(CHANGELOG, "9.9.9") }
    assert_match(/no "## \[9.9.9\]" section/, error.message)
  end

  def test_empty_section
    assert_raises(ReleaseNotes::MissingSection) do
      ReleaseNotes.extract("## [1.0.0] - 2026-01-01\n\n## [0.9.0]\n\n- x\n", "1.0.0")
    end
  end

  def test_real_changelog_has_the_current_version
    path = File.expand_path("../CHANGELOG.md", __dir__)
    notes = ReleaseNotes.extract(File.read(path), RailsAgentKit::VERSION)
    assert_includes notes, "rails-agent-kit -v #{RailsAgentKit::VERSION}"
  end
end
