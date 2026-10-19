# Releasing

The maintainer cuts releases. Versions follow [SemVer](https://semver.org/), and the changelog follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

`main` is protected, so the release commit lands through a **release PR** like any other change. Publishing is
automated: pushing a `vX.Y.Z` tag on the merge commit runs
[`.github/workflows/release.yml`](.github/workflows/release.yml), which publishes to RubyGems with
[trusted publishing](https://guides.rubygems.org/trusted-publishing/). That uses OIDC, so no API key and no MFA
prompt are needed.

## Release steps

1. **Main is green.** CI passes on `main`.
2. **Release PR.** From an up-to-date `main`, create a branch `release/vX.Y.Z` and change exactly two things:
   - `CHANGELOG.md`: rename `## [Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD`, add a fresh empty `## [Unreleased]`
     above it, and update the compare links at the bottom. Then edit the section so it reads well as release
     notes (see [Writing the changelog](#writing-the-changelog)): add the lead paragraph, an `### Upgrading`
     note if users need to act, and `### Thanks` when others contributed.
   - `lib/rails_agent_kit/version.rb`: bump `RailsAgentKit::VERSION` to `X.Y.Z`.

   Open the PR titled `Release vX.Y.Z` and label it `skip-changelog`.
3. **Merge.** Once the required checks (Ruby 3.2, 3.3, 3.4, 4.0) are green, squash-merge it:
   `gh pr merge --squash --delete-branch`.
4. **Tag the merge commit** and push the tag:

   ```sh
   git checkout main && git pull --ff-only
   git log -1 --oneline   # must be the "Release vX.Y.Z" squash commit
   git tag -a vX.Y.Z -m "rails-agent-kit X.Y.Z"
   git push origin vX.Y.Z
   ```

5. **The workflow publishes.** `release.yml` does four things:
   - runs the CI matrix
   - checks that the tag matches `RailsAgentKit::VERSION` (and fails otherwise)
   - builds the gem and pushes it via trusted publishing (`rubygems/release-gem`)
   - creates the GitHub release titled `rails-agent-kit X.Y.Z` from the version's `CHANGELOG.md` section
     (`script/release_notes.rb`)

   If the `release` environment has a required reviewer, approve the deployment in the Actions run.
6. **Verify:**
   - the workflow run is green
   - `gem info rails-agent-kit -r` shows `X.Y.Z`
   - <https://rubygems.org/gems/rails-agent-kit> lists the new version
   - the GitHub release exists and reads the way `ruby script/release_notes.rb X.Y.Z` printed it
7. **Announce** the release.

## Trusted publisher configuration

It's already configured on rubygems.org for `rails-agent-kit`:

| Field | Value |
| --- | --- |
| Repository owner | `afurm` |
| Repository name | `rails-agent-kit` |
| Workflow filename | `release.yml` |
| Environment | `release` |

If you rename the workflow file or the environment, update the trusted publisher to match, or publishing fails.

## Fallback: manual publish

Use this only if the workflow can't publish (for example, a RubyGems outage, or a broken trusted publisher
config). The tag and the merged release PR stay the same:

1. `gem build rails-agent-kit.gemspec -o pkg/rails-agent-kit-X.Y.Z.gem`, then check the contents with
   `tar -xOf pkg/*.gem data.tar.gz | tar -tz` (lib, exe, skills, README, CHANGELOG, LICENSE).
2. `gem push pkg/rails-agent-kit-X.Y.Z.gem`. **The manual path needs the maintainer's MFA**: the account has MFA
   enabled and the gemspec sets `rubygems_mfa_required`, so pass a current OTP (`GEM_HOST_OTP_CODE=…`) or approve
   the WebAuthn link that `gem push` prints. Never commit credentials.
3. Check that the sha256 from `https://rubygems.org/api/v1/versions/rails-agent-kit.json` matches
   `sha256sum pkg/*.gem`.
4. `gem push` doesn't create a GitHub release, so create it yourself:
   `ruby script/release_notes.rb X.Y.Z > notes.md && gh release create vX.Y.Z --verify-tag --title "rails-agent-kit X.Y.Z" --notes-file notes.md`.

## Writing the changelog

The `CHANGELOG.md` section for a version **is** its GitHub release, so write it for users:

```markdown
## [0.2.0] - 2026-11-02

rails-agent-kit 0.2.0 keeps large schemas out of your agent's context: a compact overview by default,
several tables per call, and a name search.

### Upgrading

`rails_schema` with no arguments now returns the overview. Pass `detail: "full"` for the previous output.

### Added

- **Find tables and columns by name.** `rails_schema` `search` matches table and column names,
  for example `search: "email"`. By @afurm. (#12)

### Fixed

- **Parse check constraints in structure.sql.** By @someone; thanks @reporter. (#15)

### Known limitations

- `db/structure.sql` parsing is best effort.

### Thanks

Thanks to @someone for the fix and @reporter for the report.
```

- **Lead paragraph:** one or two sentences on what the release brings, naming the main changes.
- **Entries:** start with the outcome in bold, as a short imperative sentence ("**Find tables and columns by
  name.**"), then the details, with the exact parameter or command in backticks. End with `By @author.`, add
  `thanks @reporter` when someone reported it, and link the PR or issue (`(#12)`).
- **Headings:** Keep a Changelog's `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed` and `Security`, plus
  the optional `Upgrading`, `Known limitations` and `Thanks`. Leave out internal changes users won't notice.

`script/release_notes.rb` turns the section into release notes in this order: the lead paragraph, a
`bundle add rails-agent-kit --version X.Y.Z` snippet with the RubyGems link, the upgrading note, the change
lists (`Added` becomes **New**), Known limitations, Thanks, and a **Full changelog** compare link. Hard-wrapped lines are
joined, because GitHub shows every newline in a release body. Preview it with `ruby script/release_notes.rb X.Y.Z`. Releases are titled `rails-agent-kit X.Y.Z`, and tags are `vX.Y.Z`.

## Cadence

- **Patch** (`0.2.1`): ship fixes as soon as they're merged, especially install or compatibility breaks.
- **Minor** (`0.3.0`): when a set of features is ready. Before 1.0, a minor release may include breaking
  changes, which go under `### Upgrading`.
- Big changes can ship release candidates first (`v1.0.0.rc1`), marked as pre-releases on GitHub.

## Labels

Maintainers label every PR. `.github/release.yml` uses the labels to group merged PRs in GitHub's
auto-generated notes ("Generate release notes"), which is a handy checklist of PRs and contributors when you
write the changelog:

| Label | Section |
| --- | --- |
| `breaking-change` | Breaking changes |
| `feature` (or `enhancement`) | New |
| `fix` (or `bug`) | Fixed |
| `docs` (or `documentation`) | Documentation |
| `internal` (and anything unlabeled) | Maintenance |
| `skip-changelog` | Excluded |

## Never

- Push directly to `main` or force-push it. The ruleset rejects both.
- Move or re-create an existing tag, or re-publish a version that's already on RubyGems. If a release is broken,
  ship a patch version instead (yanking is the maintainer's call).
