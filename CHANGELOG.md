# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/). Each version's section becomes its GitHub release notes; see
[RELEASING.md](RELEASING.md#writing-the-changelog) for the entry style.

## [Unreleased]

### Added

- **`rails_routes` boots the app with the app's own Ruby.** It reads the pinned version from `.ruby-version`,
  `.tool-versions`, `mise.toml` or the Gemfile `ruby` directive and runs the matching mise, rbenv, asdf or chruby
  install directly, so it works even when the editor starts the server without your shell profile. The answer
  reports the Ruby it used as `ruby`. If the pinned Ruby isn't installed, it says which version to install instead
  of returning a boot error. `RAILS_AGENT_KIT_ROUTES_COMMAND` still overrides everything. By @afurm.
- **Connect every agent with one command.** `rails-agent-kit init` writes `.cursor/mcp.json`, `.mcp.json` (Claude
  Code) and `.vscode/mcp.json` with project-relative paths, merges into existing files without touching other
  servers, chooses `bundle exec` when the app's Gemfile has the gem, installs the bundled skills for Cursor and
  Claude Code, and prints the `~/.codex/config.toml` snippet for Codex. It's idempotent; `--dry-run` previews,
  `--agent` picks clients and `--force` replaces an edited entry. By @afurm.
- **Ask for several tables at once.** `rails_schema` takes `table` as an array or a comma-separated list, so
  related tables come back in one call. Names that don't exist are listed in `missing_tables`. By @afurm.
- **Find tables and columns by name.** `rails_schema` `search` is a case-insensitive match on table and column
  names, for example `search: "email"`. By @afurm.
- **Choose how much schema you get.** `rails_schema` `detail` is `overview` or `full`. By @afurm.

- **A documentation site** at <https://afurm.github.io/rails-agent-kit/>: getting started, a page per tool with
  example output, the CLI reference, the agent skill and compatibility. The gemspec links to it as
  `documentation_uri`. By @afurm.

### Changed

- **`rails_schema` with no arguments returns a compact overview** instead of the whole schema: each table's
  column count, non-default primary key and foreign key targets. Pass `detail: "full"` for the previous output.
  On a generated 300-table schema the default answer drops from about 1.2 MB to 23 KB. By @afurm.
- **Large answers stay bounded.** A `rails_schema` answer over 60 KB is replaced by the overview with
  `truncated: true` and a note on how to narrow the request. By @afurm.
- **Smaller responses.** Tools return compact JSON instead of pretty-printed JSON, which roughly halves their
  size, and the server instructions describe the overview, then `table:` / `search:` flow. By @afurm.
- **Tested on Ruby 4.0.** CI runs Ruby 3.2, 3.3, 3.4 and 4.0, plus `ruby-head` (allowed to fail). By @afurm.
- **Project docs and automated releases.** A rewritten README; CONTRIBUTING, CODE_OF_CONDUCT (Contributor
  Covenant 2.1), SECURITY, RELEASING and ROADMAP; issue and PR templates. Pushing a `vX.Y.Z` tag publishes the
  gem with RubyGems trusted publishing and creates the GitHub release, titled `rails-agent-kit X.Y.Z`, from
  this changelog. By @afurm. (#1)

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
