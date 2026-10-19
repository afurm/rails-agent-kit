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

    rails-agent-kit 0.2.0 keeps large schemas out of the agent's context.

    ### Fixed

    - **A bug.** By @someone. (#7)

    ### Thanks

    Thanks to @someone for the report.

    ### Upgrading

    Run `bundle update rails-agent-kit`.

    ### Added

    - **Compact `rails_schema` overview.** By @afurm. (#3)

    ## [0.1.0] - 2026-10-17

    ### Added

    - First release.

    [Unreleased]: https://github.com/afurm/rails-agent-kit/compare/v0.2.0...HEAD
    [0.2.0]: https://github.com/afurm/rails-agent-kit/compare/v0.1.0...v0.2.0
    [0.1.0]: https://github.com/afurm/rails-agent-kit/releases/tag/v0.1.0
  MD

  def notes
    @notes ||= ReleaseNotes.extract(CHANGELOG, "v0.2.0")
  end

  def test_starts_with_the_lead_then_the_install_snippet
    assert notes.start_with?("rails-agent-kit 0.2.0 keeps large schemas out of the agent's context.\n\n```sh\n")
    assert_includes notes, "bundle add rails-agent-kit --version 0.2.0 --group development"
    assert_includes notes, "gem install rails-agent-kit -v 0.2.0"
    assert_includes notes, "https://rubygems.org/gems/rails-agent-kit/versions/0.2.0"
  end

  def test_upgrading_follows_the_install_snippet_without_a_heading
    assert_operator notes.index("Run `bundle update"), :>, notes.index("```sh")
    assert_operator notes.index("Run `bundle update"), :<, notes.index("## New")
    refute_includes notes, "## Upgrading"
  end

  def test_sections_are_renamed_and_ordered
    assert_includes notes, "## New\n\n- **Compact `rails_schema` overview.** By @afurm. (#3)"
    assert_includes notes, "## Fixed\n\n- **A bug.** By @someone. (#7)"
    refute_includes notes, "### "
    order = ["## New", "## Fixed", "## Thanks", "**Full changelog**"].map { |s| notes.index(s) }
    assert_equal order.sort, order
  end

  def test_ends_with_the_full_changelog_link
    assert notes.end_with?("**Full changelog**: https://github.com/afurm/rails-agent-kit/compare/v0.1.0...v0.2.0\n")
  end

  def test_excludes_other_versions
    refute_includes notes, "First release"
    refute_includes notes, "not released yet"
  end

  def test_first_release_has_no_lead_and_no_compare_link
    first = ReleaseNotes.extract(CHANGELOG, "0.1.0")
    assert first.start_with?("```sh\nbundle add rails-agent-kit --version 0.1.0")
    assert_includes first, "## New\n\n- First release."
    refute_includes first, "[Unreleased]:"
    refute_includes first, "Full changelog"
  end

  def test_hard_wrapped_lines_are_joined_but_code_and_lists_are_kept
    text = ReleaseNotes.unwrap(<<~MD.strip)
      A lead that is
      wrapped.

      - **One.** Wrapped
        continuation.
        - nested item
      - Two.

      ```sh
      gem install x
      echo y
      ```
    MD
    assert_equal <<~MD.strip, text
      A lead that is wrapped.

      - **One.** Wrapped continuation.
        - nested item
      - Two.

      ```sh
      gem install x
      echo y
      ```
    MD
  end

  def test_title
    assert_equal "rails-agent-kit 0.2.0", ReleaseNotes.title("v0.2.0")
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
    assert_includes notes, "--version #{RailsAgentKit::VERSION}"
  end
end
