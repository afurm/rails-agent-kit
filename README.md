<div align="center">

<h1>rails-agent-kit</h1>

<strong>Ground truth about your Rails app, for coding agents</strong>

<p>A read-only MCP server that gives Cursor, Claude Code, Codex and other MCP clients your app's real schema and
routes, plus a Rails 8 skill that tells the agent to check them before it writes code.</p>

[Documentation](https://afurm.github.io/rails-agent-kit/) · [Install](#installation) · [Connect your agent](#connect-your-agent) · [Tools](#tools) · [Changelog](CHANGELOG.md) · [Roadmap](ROADMAP.md)

[![Gem Version](https://img.shields.io/gem/v/rails-agent-kit?color=CC342D&logo=rubygems&logoColor=white)](https://rubygems.org/gems/rails-agent-kit)
[![Gem Downloads](https://img.shields.io/gem/dt/rails-agent-kit)](https://rubygems.org/gems/rails-agent-kit)
[![CI](https://github.com/afurm/rails-agent-kit/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/afurm/rails-agent-kit/actions/workflows/ci.yml)
[![Ruby](https://img.shields.io/badge/ruby-3.2%20%7C%203.3%20%7C%203.4%20%7C%204.0-CC342D?logo=ruby&logoColor=white)](#compatibility)
[![License: MIT](https://img.shields.io/github/license/afurm/rails-agent-kit)](LICENSE)

</div>

> [!NOTE]
> rails-agent-kit is early (v0.1.0), and the API may change before 1.0. Using it? Tell us how it went in
> [Discussions](https://github.com/afurm/rails-agent-kit/discussions) or [open an issue](https://github.com/afurm/rails-agent-kit/issues).

---

## Look it up instead of guessing

Agents writing Rails code guess all the time. *Is it `user.full_name` or `user.name`? Is the column nullable? Is
the helper `post_comments_path` or `comments_path`?* Each wrong guess is broken code and another review round.
rails-agent-kit lets the agent ask your app.

* **Schema:** tables, columns, indexes and foreign keys from `db/schema.rb`, parsed statically. It never boots
  the app or connects to a database. `db/structure.sql` gets a best-effort parse.
* **Schema overview and search (on `main`, not yet released):** a compact overview by default, several tables
  in one call, and a name search across tables and columns, so large schemas don't flood the agent's context.
* **Routes:** every route with its name, verb, path, `controller#action` and source line, from your app's own
  `bin/rails routes --expanded`. Engines and route concerns resolve exactly as Rails sees them.
* **Routes without booting:** point it at a saved routes dump, or run the routes command in Docker.
* **One-command setup (on `main`, not yet released):** `rails-agent-kit init` connects Cursor, Claude Code, VS Code
  and Codex, and installs the skill.
* **Rails 8 conventions skill:** an Agent Skill for Cursor and Claude Code, installed with
  `rails-agent-kit install-skills`.
* **Read-only and local:** a stdio server your client starts. It doesn't listen on a network port.

## See what your agent sees

The agent calls the tools itself. These are real answers for the small blog app in
[`test/fixtures/blog_app`](test/fixtures/blog_app), pretty-printed (the server sends compact JSON).

```js
// rails_schema {}  (the overview, on main; trimmed)
{
  "source": "db/schema.rb",
  "table_count": 4,
  "tables": [
    { "name": "comments", "columns": 6, "references": ["posts", "users"] },
    { "name": "posts", "columns": 10, "references": ["users"] },
    { "name": "posts_tags", "columns": 2, "primary_key": false },
    { "name": "users", "columns": 7 }
  ]
}
```

```js
// rails_schema { "search": "email" }  (on main; trimmed)
{ "match_count": 1, "matches": [{ "table": "users", "columns": [{ "name": "email", "type": "string", "null": false }] }] }
```

```js
// rails_schema { "table": "comments" }  (trimmed)
{
  "tables": [{
    "name": "comments",
    "columns": [
      { "name": "post_id", "type": "bigint", "null": false },
      { "name": "body", "type": "text", "null": false }
    ],
    "indexes": [{ "name": "index_comments_on_post_id", "columns": ["post_id"], "unique": false }]
  }],
  "foreign_keys": [{ "from_table": "comments", "to_table": "users", "column": "user_id", "on_delete": "cascade" }]
}
```

```js
// rails_routes { "filter": "comments" }  (trimmed)
{
  "total": 7,
  "count": 2,
  "routes": [
    { "name": "post_comments", "verb": "POST", "path": "/posts/:post_id/comments(.:format)",
      "controller_action": "comments#create", "source_location": "config/routes.rb:3" }
  ]
}
```

## Installation

```sh
gem install rails-agent-kit
```

or, inside your Rails app:

```sh
bundle add rails-agent-kit --group development
```

Requires Ruby 3.2+.

## Connect your agent

### One command (on `main`, not yet released)

From your app's root:

```sh
bundle add rails-agent-kit --group development
bundle exec rails-agent-kit init
```

`init` writes the MCP config for Cursor (`.cursor/mcp.json`), Claude Code (`.mcp.json`) and VS Code
(`.vscode/mcp.json`), using project-relative paths so you can commit the files for your whole team. It adds
rails-agent-kit next to the servers you already have, picks `bundle exec` or the installed gem for you, installs the
Rails 8 skill for Cursor and Claude Code, and prints the snippet for Codex's global `~/.codex/config.toml`.
Running it again changes nothing. Preview with `--dry-run`, or pick clients with `--agent cursor,claude`.

### By hand

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
rails-agent-kit init [--root PATH] [--agent LIST] [--dry-run] [--force] [--no-skills]
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
| Ruby | 3.2, 3.3, 3.4, 4.0 | Tested in CI (`ruby-head` runs too, allowed to fail) |
| Rails (`db/schema.rb` format) | 8.0 | Covered by test fixtures |
| Rails | 7.2, 8.1 | Expected to work, but not yet covered by CI ([planned](ROADMAP.md)) |
| MCP clients | Cursor, Claude Code, Codex, Claude Desktop, or any stdio MCP client | Configuration shown above |

The bundled skill targets Rails 8 conventions. On Rails 7.x, the tools work the same, but some skill advice
(e.g. `params.expect` and Solid Queue defaults) won't apply.

## Documentation

The full guide lives at **[afurm.github.io/rails-agent-kit](https://afurm.github.io/rails-agent-kit/)**: getting
started, a page per tool with example output, the CLI reference, the agent skill and compatibility.

[Connect your agent](#connect-your-agent) · [Tools](#tools) · [CLI reference](#cli-reference) ·
[Changelog](CHANGELOG.md) · [Roadmap](ROADMAP.md) · [Releasing](RELEASING.md) · [Security](SECURITY.md)

## Community

* **Questions and ideas:** [GitHub Discussions](https://github.com/afurm/rails-agent-kit/discussions)
* **Bugs:** [open an issue](https://github.com/afurm/rails-agent-kit/issues/new/choose) with your Ruby, Rails
  and MCP client versions
* **Vulnerabilities:** report them privately, as described in [SECURITY.md](SECURITY.md)

Everyone taking part follows the [Code of Conduct](CODE_OF_CONDUCT.md).

## Contributing

Pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md), then:

```sh
gh repo fork afurm/rails-agent-kit --clone && cd rails-agent-kit
bundle install
bundle exec rake test
```

## License

[MIT](LICENSE) © Andrii Furmanets
