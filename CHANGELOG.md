# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/). Each version's section becomes its GitHub release notes; see
[RELEASING.md](RELEASING.md#writing-the-changelog) for the entry style.

## [Unreleased]

### Added

- **`rails_schema` reads the rest of a real schema.** Postgres enums (`create_enum`, with each `t.enum` column's
  `enum_type` and `values`), check, exclusion and unique constraints, composite primary keys, `create_schema` and
  tables in other schemas, expression indexes, scenic views (with indexes on materialized views) and SQLite
  full-text search tables. Virtual columns report their real type with `virtual`, `as` and `stored`. By @afurm.
- **Warnings instead of silent gaps.** A line inside `create_table` the parser doesn't understand, or a top-level
  statement it skips (a trigger, an `execute`), is listed in `warnings` with its line number, in every
  `rails_schema` answer. By @afurm.
- **Engine routes say where they're mounted.** Routes listed under an engine in `bin/rails routes --expanded`
  carry `engine` and `mounted_at`, since their paths are relative to the mount point. By @afurm.
- **Tested against real apps.** A test corpus of `rails new` apps on Rails 7.2, 8.0 and 8.1 (SQLite and
  PostgreSQL, with Devise, Sidekiq::Web, Active Storage and a mounted engine) plus the Mastodon and Forem schemas.
  Table, column and route counts must match what the booted app and PostgreSQL report. By @afurm.

### Fixed

- **`t.check_constraint` is no longer read as a column** named after its expression, which added phantom columns
  to tables with check constraints. By @afurm.
- **Expression indexes are no longer dropped.** `t.index "lower(email)"` and `add_index` with an SQL expression
  containing quotes were skipped; they're now listed with the expression. By @afurm.
- **Tables dumped as `public.users`** (apps with several schemas on the search path) are reported as `users`,
  so `table: "users"` finds them; enums get the same treatment. By @afurm.
- **Statements that span several lines** (long `create_table` options, multi-line defaults) and heredocs are
  parsed as one statement, and escaped characters in string defaults (`\n`, `\"`) are unescaped. By @afurm.

## [0.2.0] - 2026-10-23

rails-agent-kit 0.2.0 keeps large schemas out of your agent's context and makes setup one command:
`rails_schema` starts with a compact overview and can search and fetch several tables at once,
`rails-agent-kit init` connects Cursor, Claude Code, VS Code and Codex, the Rails 8 skill now reaches every agent
that reads `AGENTS.md`, and `rails_routes` boots your app with the Ruby it pins.

### Upgrading

`rails_schema` with no arguments now returns a compact overview instead of the whole schema. Pass
`detail: "full"` for the previous output, or `table:` for the tables you need. If you configured clients by hand,
you can keep that config; `rails-agent-kit init` only adds what's missing.

### Added

- **Connect every agent with one command.** `rails-agent-kit init` writes `.cursor/mcp.json`, `.mcp.json` (Claude
  Code) and `.vscode/mcp.json` with project-relative paths, merges into existing files without touching other
  servers, chooses `bundle exec` when the app's Gemfile has the gem, installs the bundled skills, and prints the
  `~/.codex/config.toml` snippet for Codex. It's idempotent; `--dry-run` previews, `--agent` picks clients and
  `--force` replaces an edited entry. By @afurm. (#5)
- **Give Codex, Copilot and Gemini CLI the Rails 8 skill.** `install-skills --agent codex` adds the skill to
  `AGENTS.md`, which Codex, Cursor, GitHub Copilot, Windsurf, Zed and others read; `--agent copilot` writes
  `.github/copilot-instructions.md` and `--agent gemini` writes `GEMINI.md`. The text sits between
  `<!-- rails-agent-kit:start -->` and `<!-- rails-agent-kit:end -->` markers, so the rest of your file is never
  touched and re-running updates only that block. `init` does this for Codex. By @afurm. (#7)
- **`rails_routes` boots the app with the app's own Ruby.** It reads the pinned version from `.ruby-version`,
  `.tool-versions`, `mise.toml` or the Gemfile `ruby` directive and runs the matching mise, rbenv, asdf or chruby
  install directly, so it works even when the editor starts the server without your shell profile. The answer
  reports the Ruby it used as `ruby`. If the pinned Ruby isn't installed, it says which version to install instead
  of returning a boot error. `RAILS_AGENT_KIT_ROUTES_COMMAND` still overrides everything. By @afurm. (#6)
- **Ask for several tables at once.** `rails_schema` takes `table` as an array or a comma-separated list, so
  related tables come back in one call. Names that don't exist are listed in `missing_tables`. By @afurm.
- **Find tables and columns by name.** `rails_schema` `search` is a case-insensitive match on table and column
  names, for example `search: "email"`. By @afurm.
- **Choose how much schema you get.** `rails_schema` `detail` is `overview` or `full`. By @afurm.
- **A documentation site** at <https://afurm.github.io/rails-agent-kit/>: getting started, a page per tool with
  example output, the CLI reference, supported agents, the agent skill and compatibility. The gemspec links to it
  as `documentation_uri`. By @afurm. (#3)

### Changed

- **`rails_schema` with no arguments returns a compact overview** instead of the whole schema: each table's
  column count, non-default primary key and foreign key targets. On a generated 300-table schema the default
  answer drops from about 1.2 MB to 23 KB. By @afurm.
- **Large answers stay bounded.** A `rails_schema` answer over 60 KB is replaced by the overview with
  `truncated: true` and a note on how to narrow the request. By @afurm.
- **Smaller responses.** Tools return compact JSON instead of pretty-printed JSON, which roughly halves their
  size, and the server instructions describe the overview, then `table:` / `search:` flow. By @afurm.
- **Tested on Ruby 4.0.** CI runs Ruby 3.2, 3.3, 3.4 and 4.0, plus `ruby-head` (allowed to fail). By @afurm.
- **Project docs and automated releases.** A rewritten README; CONTRIBUTING, CODE_OF_CONDUCT (Contributor
  Covenant 2.1), SECURITY, RELEASING and ROADMAP; issue and PR templates. Releases are published from a tag with
  RubyGems trusted publishing. By @afurm. (#1)

### Known limitations

- `db/structure.sql` parsing is best effort: foreign keys and constraints aren't extracted yet.
- Multi-database apps: only the primary database's schema is read.

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

[Unreleased]: https://github.com/afurm/rails-agent-kit/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/afurm/rails-agent-kit/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/afurm/rails-agent-kit/releases/tag/v0.1.0
