# Releasing

The maintainer cuts releases. Versions follow [SemVer](https://semver.org/), and the changelog follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Automated release (trusted publishing)

[`.github/workflows/release.yml`](.github/workflows/release.yml) runs when a `vX.Y.Z` tag is pushed. It runs the
CI matrix, checks that the tag matches `RailsAgentKit::VERSION`, builds the gem and pushes it with
[RubyGems trusted publishing](https://guides.rubygems.org/trusted-publishing/) (OIDC, so no API key and no OTP),
then creates the GitHub release from the version's `CHANGELOG.md` section (`ruby script/release_notes.rb X.Y.Z`).

**One-time setup (maintainer, on rubygems.org):** open the gem, then **Trusted publishers → Create**:

| Field | Value |
| --- | --- |
| Repository owner | `afurm` |
| Repository name | `rails-agent-kit` |
| Workflow filename | `release.yml` |
| Environment | `release` |

The `release` GitHub environment is created on the first run. Add a required reviewer to it under
**Settings → Environments** if every publish should wait for a click.

With that in place, a release is steps 1–4 below, then `git tag -a vX.Y.Z -m "rails-agent-kit X.Y.Z" && git push
origin vX.Y.Z`. Check the workflow run, the gem page and the GitHub release (step 7). Steps 5–9 are the manual
fallback.

## Checklist

1. **Main is green.** CI passes on `main`, and `bundle exec rake test` passes locally.
2. **Changelog.** Rename `## [Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD`, add a fresh empty `## [Unreleased]`
   above it, and update the compare links at the bottom.
3. **Version.** Bump `RailsAgentKit::VERSION` in `lib/rails_agent_kit/version.rb`.
4. **Commit and push:** `git commit -am "Release vX.Y.Z" && git push origin main`. Wait for CI to pass.
5. **Build:** `gem build rails-agent-kit.gemspec -o pkg/rails-agent-kit-X.Y.Z.gem`, then check what got packaged
   with `tar -xOf pkg/*.gem data.tar.gz | tar -tz` (lib, exe, skills, README, CHANGELOG, LICENSE).
6. **Push to RubyGems:** `gem push pkg/rails-agent-kit-X.Y.Z.gem`.
   **This needs the maintainer's MFA approval.** The RubyGems account has MFA enabled, and the gemspec sets
   `rubygems_mfa_required`, so an API key alone isn't enough. Either pass a current OTP
   (`GEM_HOST_OTP_CODE=123456 gem push …`) or approve the WebAuthn link that `gem push` prints within its timeout.
   Never commit credentials. The automated release above removes this step.
7. **Verify:** `gem info rails-agent-kit -r` shows the new version, and the sha256 from
   `https://rubygems.org/api/v1/versions/rails-agent-kit.json` matches `sha256sum pkg/*.gem`.
8. **Tag** the release commit and push the tag:
   `git tag -a vX.Y.Z -m "rails-agent-kit X.Y.Z" && git push origin vX.Y.Z`.
9. **GitHub release:** `gh release create vX.Y.Z --verify-tag --title "vX.Y.Z" --notes-file notes.md`.
   Start `notes.md` from `ruby script/release_notes.rb X.Y.Z` (the CHANGELOG section, install lines and links) and
   add **Highlights** at the top.
   `gh release create --generate-notes` drafts the PR list, grouped by the categories in `.github/release.yml`.
10. **Announce:** draft posts for the maintainer to publish.

## Labels and release notes

`.github/release.yml` groups merged PRs by label:

| Label | Section |
| --- | --- |
| `breaking-change` | Breaking changes |
| `feature` (or `enhancement`) | Features |
| `fix` (or `bug`) | Fixes |
| `docs` (or `documentation`) | Docs |
| `internal` (and anything unlabeled) | Internal |
| `skip-changelog` | Excluded |

## Never

Force-push to `main`, re-tag an existing version, or re-push a version that's already on RubyGems. If a release
is broken, ship a patch version instead (yanking is the maintainer's call).
