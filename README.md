# rails-agent-kit

**Give coding agents ground truth about your Rails app: its real schema and routes, over MCP, without booting the app for the schema.**

[![Gem Version](https://img.shields.io/gem/v/rails-agent-kit?color=CC342D&logo=rubygems&logoColor=white)](https://rubygems.org/gems/rails-agent-kit)
[![CI](https://github.com/afurm/rails-agent-kit/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/afurm/rails-agent-kit/actions/workflows/ci.yml)
[![Ruby](https://img.shields.io/badge/ruby-3.2%20%7C%203.3%20%7C%203.4-CC342D?logo=ruby&logoColor=white)](#compatibility)
[![License: MIT](https://img.shields.io/github/license/afurm/rails-agent-kit)](LICENSE)

rails-agent-kit is a small [Model Context Protocol](https://modelcontextprotocol.io) server plus agent skills
for Cursor, Claude Code, Codex and any other MCP client.

> **Status:** early (v0.1.0). The API may change before 1.0. [Feedback and issues welcome.](https://github.com/afurm/rails-agent-kit/issues)

## Why

Agents writing Rails code guess constantly. *Is it `user.full_name` or `user.name`? Is the column nullable?
Is the helper `post_comments_path` or `comments_path`?* Every wrong guess means broken code and another review cycle.

rails-agent-kit lets the agent **look it up instead of guessing**. It reads your app's actual schema and routes,
and ships a Rails 8 skill that tells the agent to check them before it edits code.

## Install

```sh
gem install rails-agent-kit
```

or, inside your Rails app:

```sh
bundle add rails-agent-kit --group development
```

Requires Ruby 3.2+.

## Quickstart

Replace `/path/to/your/rails/app` with the absolute path to your app.

<details open>
<summary><b>Cursor</b></summary>

`.cursor/mcp.json` in your app (or `~/.cursor/mcp.json`):

```json
{
  "mcpServers": {
    "rails-agent-kit": {
      "command": "rails-agent-kit",
      "args": ["--root", "/path/to/your/rails/app"]
    }
  }
}
```

</details>

<details open>
<summary><b>Claude Code</b></summary>

```sh
claude mcp add rails-agent-kit -- rails-agent-kit --root /path/to/your/rails/app
```

</details>

<details open>
<summary><b>Codex</b></summary>

```sh
codex mcp add rails-agent-kit -- rails-agent-kit --root /path/to/your/rails/app
```

or in `~/.codex/config.toml`:

```toml
[mcp_servers.rails-agent-kit]
command = "rails-agent-kit"
args = ["--root", "/path/to/your/rails/app"]
```

</details>

<details>
<summary><b>Claude Desktop and other MCP clients</b></summary>

Any client that launches stdio MCP servers works. Claude Desktop's `claude_desktop_config.json` takes the same
`mcpServers` block as Cursor above.

</details>

<details>
<summary><b>Installed with <code>bundle add</code> instead of <code>gem install</code>?</b></summary>

Run it through the app's bundle:

```json
{
  "mcpServers": {
    "rails-agent-kit": {
      "command": "bundle",
      "args": ["exec", "rails-agent-kit", "--root", "/path/to/your/rails/app"],
      "env": { "BUNDLE_GEMFILE": "/path/to/your/rails/app/Gemfile" }
    }
  }
}
```

```sh
claude mcp add rails-agent-kit -e BUNDLE_GEMFILE=/path/to/your/rails/app/Gemfile \
  -- bundle exec rails-agent-kit --root /path/to/your/rails/app
```

</details>

To also add the Rails 8 conventions skill (optional; Cursor and Claude Code), see [Agent skill](#agent-skill-rails-8-conventions):

```sh
rails-agent-kit install-skills --root /path/to/your/rails/app                 # Cursor
rails-agent-kit install-skills --root /path/to/your/rails/app --agent claude  # Claude Code
```

## Tools

Both tools are read-only and return JSON.

| Tool | Parameters | Returns | Boots the app? |
| --- | --- | --- | --- |
| `rails_schema` | All optional. `table`: one exact name, an array or a comma-separated list. `search`: case-insensitive part of a table or column name. `detail`: `overview` or `full` | With no arguments, a compact overview (each table's column count, non-default primary key and foreign key targets). With `table`, full columns (type, null, default, limit, …), indexes and foreign keys. With `search`, the matching tables and columns | **No.** Parses `db/schema.rb` statically, with a best-effort fallback to `db/structure.sql` |
| `rails_routes` | `filter` (optional, case-insensitive substring of name, path, verb or `controller#action`) | Each route's name, verb, path, `controller#action` and source location | **Yes.** Runs `bin/rails routes --expanded`. If that fails or times out, it explains why and returns the raw `config/routes.rb` |

Responses are compact (single-line) JSON. Agents usually call `rails_schema` with no arguments first, so that
answer stays small even on large apps: a generated 300-table schema gives about 23 KB, where the full dump is
over 1 MB. Any `rails_schema` answer over 60 KB comes back as the overview plus a note on how to narrow the
request (`truncated: true`).

## CLI reference

```text
rails-agent-kit [--root PATH] [--routes-file FILE]       # start the MCP server on stdio
rails-agent-kit install-skills [--root PATH] [--agent cursor|claude] [--force] [SKILL...]
rails-agent-kit --version
```

| Option / env var | Purpose |
| --- | --- |
| `--root PATH` | Rails app root (default: the current directory) |
| `--routes-file FILE` | Use a saved `bin/rails routes --expanded` dump instead of booting the app |
| `RAILS_AGENT_KIT_ROUTES_TIMEOUT` | Seconds to wait for `bin/rails routes` (default `60`) |
| `RAILS_AGENT_KIT_ROUTES_COMMAND` | Override the routes command, e.g. `"docker compose exec -T web bin/rails routes --expanded"`. Runs in `--root` |

If your app can't boot locally (it needs a DB, secrets or Docker), dump the routes once and point the server at
the file:

```sh
bin/rails routes --expanded > tmp/routes.txt
rails-agent-kit --root . --routes-file tmp/routes.txt
```

## How it works

- **Transport:** a stdio MCP server built on the official [`mcp` Ruby SDK](https://github.com/modelcontextprotocol/ruby-sdk).
  Your agent client starts it and talks JSON-RPC over stdin/stdout. Nothing listens on a network port.
- **Schema:** read from `db/schema.rb` with a static parser. It never loads your app or connects to a database,
  so it's fast and safe on any checkout. Apps that use `db/structure.sql` get a best-effort SQL parse.
- **Routes:** generated by your app itself (`bin/rails routes --expanded`), so engines and route concerns
  resolve exactly as Rails sees them. It runs with Bundler's environment cleared, so the app uses its own Gemfile.
- **Skill:** a Markdown [Agent Skill](https://cursor.com/docs/skills) copied into your app. It tells the agent to
  call these tools before it writes model attributes, queries, URL helpers or migrations.

## Agent skill: Rails 8 conventions

[`skills/rails-8-conventions/SKILL.md`](skills/rails-8-conventions/SKILL.md) makes the agent check `rails_schema`,
`rails_routes` and `Gemfile.lock` before it edits code. It then follows the Rails 8 defaults: `params.expect`, the
built-in authentication generator, `rate_limit`, Solid Queue/Cache/Cable, Hotwire with importmap/Propshaft,
reversible migrations, and tests in the framework the app already uses. It also covers a paired Next.js
frontend.

`install-skills` copies it to `.cursor/skills/` (default) or `.claude/skills/` (`--agent claude`). Running it again
is safe. It never overwrites a skill you've edited unless you pass `--force`.

## Compatibility

| | Versions | Status |
| --- | --- | --- |
| Ruby | 3.2, 3.3, 3.4 | Tested in CI |
| Rails (`db/schema.rb` format) | 8.0 | Covered by test fixtures |
| Rails | 7.2, 8.1 | Expected to work, but not yet covered by CI ([planned](ROADMAP.md)) |
| MCP clients | Cursor, Claude Code, Codex, Claude Desktop, or any stdio MCP client | Configuration shown above |

The bundled skill targets Rails 8 conventions. On Rails 7.x, the tools work the same, but some skill advice
(e.g. `params.expect` and Solid Queue defaults) won't apply.

## Roadmap

See [ROADMAP.md](ROADMAP.md) for what's planned next.

## Contributing

Bug reports, ideas and pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) and the
[Code of Conduct](CODE_OF_CONDUCT.md). To report a vulnerability, see [SECURITY.md](SECURITY.md).

```sh
git clone https://github.com/afurm/rails-agent-kit && cd rails-agent-kit
bundle install
bundle exec rake test
```

## License

[MIT](LICENSE) © Andrii Furmanets
