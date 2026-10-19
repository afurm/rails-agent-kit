# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `rails_schema` takes `table` as an array or a comma-separated list, so related tables come back in one call.
  Tables that don't exist are listed in `missing_tables`.
- `rails_schema` `search`: a case-insensitive match on table and column names (for example `search: "email"`).
- `rails_schema` `detail`: `overview` or `full`.
- Release automation: pushing a `vX.Y.Z` tag runs CI, publishes the gem with RubyGems trusted publishing and
  creates the GitHub release from the CHANGELOG (`.github/workflows/release.yml`, `script/release_notes.rb`).
- Project docs: CONTRIBUTING, CODE_OF_CONDUCT (Contributor Covenant 2.1), SECURITY, RELEASING, ROADMAP,
  issue and PR templates, CODEOWNERS, and release-note categories (`.github/release.yml`).

### Changed

- CONTRIBUTING and RELEASING describe the pull-request-only workflow for `main` (required checks, squash
  merges) and releases through a release PR and a version tag.
- **`rails_schema` with no arguments now returns a compact overview** (each table's column count, non-default
  primary key and foreign key targets) instead of the whole schema. Pass `detail: "full"` for the old output. On
  a generated 300-table schema the default answer drops from about 1.2 MB to 23 KB.
- `rails_schema` answers over 60 KB are replaced by the overview with `truncated: true` and a note on how to
  narrow the request.
- Tool responses are compact JSON instead of pretty-printed, which roughly halves their size.
- The server instructions describe the overview, then `table:` / `search:` flow.
- CI now also runs on Ruby 4.0, plus `ruby-head` (allowed to fail).
- README rewritten: quickstarts for Cursor, Claude Code and Codex, a tools and CLI reference, how it works, and
  a compatibility table.

## [0.1.0] - 2026-10-17

### Added

- An MCP stdio server (`rails-agent-kit`, built on the official `mcp` Ruby SDK) with two read-only tools:
  - `rails_schema`: tables, columns, indexes and foreign keys. Parsed statically from `db/schema.rb` without
    booting the app, with a best-effort fallback to `db/structure.sql`. Takes an optional `table` filter.
  - `rails_routes`: verb, path, `controller#action` and name for each route, from `bin/rails routes --expanded`.
    Takes an optional `filter`. Use `--routes-file` or `RAILS_AGENT_KIT_ROUTES_COMMAND` when the app can't boot
    locally. If the routes command fails, the tool falls back to the raw `config/routes.rb`.
- A Rails 8 conventions agent skill (`skills/rails-8-conventions/SKILL.md`) for Cursor and Claude Code.
- `rails-agent-kit install-skills [--agent cursor|claude] [--force]`, which installs the bundled skills into an app.
- CI on Ruby 3.2, 3.3 and 3.4.

[Unreleased]: https://github.com/afurm/rails-agent-kit/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/afurm/rails-agent-kit/releases/tag/v0.1.0
