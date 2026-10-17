# Releasing

The maintainer cuts releases. Versions follow [SemVer](https://semver.org/), and the changelog follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
   Never commit credentials. (Planned: tag-triggered publishing via RubyGems trusted publishing, which removes this step.)
7. **Verify:** `gem info rails-agent-kit -r` shows the new version, and the sha256 from
   `https://rubygems.org/api/v1/versions/rails-agent-kit.json` matches `sha256sum pkg/*.gem`.
8. **Tag** the release commit and push the tag:
   `git tag -a vX.Y.Z -m "rails-agent-kit X.Y.Z" && git push origin vX.Y.Z`.
9. **GitHub release:** `gh release create vX.Y.Z --verify-tag --title "vX.Y.Z" --notes-file notes.md`.
   Write `notes.md` with **Highlights**, **Install**, **What's included**, and the full changelog link.
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
