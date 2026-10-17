# rails-agent-kit

A tiny [Model Context Protocol](https://modelcontextprotocol.io) server that gives coding agents
(Cursor, Claude Code, …) **ground truth about your Rails app**: its database schema and its routes.

[![Gem Version](https://badge.fury.io/rb/rails-agent-kit.svg)](https://rubygems.org/gems/rails-agent-kit)

> Status: early (v0.1.0). Feedback and issues welcome.

## Why (the 30-second version)

Agents writing Rails code constantly guess: *is it `user.full_name` or `user.name`? is the column nullable?
is the helper `post_comments_path` or `comments_path`?* Wrong guesses become broken code and wasted review cycles.
With rails-agent-kit the agent just asks:

| Tool | What it returns | Boots the app? |
| --- | --- | --- |
| `rails_schema` | Tables, columns (type, null, default, limit, …), indexes, foreign keys. Optional `table` filter. | **No** — statically parses `db/schema.rb` (falls back to a best-effort `db/structure.sql` parse). |
| `rails_routes` | Every route: name/prefix, verb, path, `controller#action`, source location. Optional `filter`. | Yes — runs `bin/rails routes --expanded` with the app's own bundle. If that fails or times out, it says why and returns the raw `config/routes.rb` instead. |

Both tools are read-only. Output is JSON.

## Install

```sh
gem install rails-agent-kit
```

Or add it to your Rails app's development group:

```sh
bundle add rails-agent-kit --group development
```

Then add the MCP server to your agent (see [MCP client config](#mcp-client-config)) and, if you like, install the Rails 8 skill:

```sh
rails-agent-kit install-skills --root /path/to/your/rails/app
```

Requires Ruby 3.2+. Runtime dependency: the official [`mcp`](https://github.com/modelcontextprotocol/ruby-sdk) Ruby SDK.

## Usage

```
rails-agent-kit [--root PATH] [--routes-file FILE]

  --root PATH          Rails app root (default: current directory)
  --routes-file FILE   Use a saved `bin/rails routes --expanded` dump instead of booting the app
```

The server speaks MCP over stdio. Environment knobs:

- `RAILS_AGENT_KIT_ROUTES_TIMEOUT` — seconds to wait for `bin/rails routes` (default `60`).
- `RAILS_AGENT_KIT_ROUTES_COMMAND` — override the routes command, e.g. `"bundle exec rails routes --expanded"`
  or `"docker compose exec -T web bin/rails routes --expanded"`. Runs in `--root`.

If your app can't boot locally (needs a DB, secrets, Docker…), dump the routes once and point the server at the file:

```sh
bin/rails routes --expanded > tmp/routes.txt
rails-agent-kit --root . --routes-file tmp/routes.txt
```

## MCP client config

Replace `/path/to/your/rails/app` with the absolute path to your app.

**Cursor**: `.cursor/mcp.json` in your Rails app, or `~/.cursor/mcp.json`:

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

If you installed it with `bundle add`, use `"command": "bundle"` and
`"args": ["exec", "rails-agent-kit", "--root", "/path/to/your/rails/app"]` instead, and add
`"env": { "BUNDLE_GEMFILE": "/path/to/your/rails/app/Gemfile" }`.

**Claude Code**:

```sh
claude mcp add rails-agent-kit -- rails-agent-kit --root /path/to/your/rails/app
# or, via the app's bundle:
claude mcp add rails-agent-kit -e BUNDLE_GEMFILE=/path/to/your/rails/app/Gemfile \
  -- bundle exec rails-agent-kit --root /path/to/your/rails/app
```

**Claude Desktop**: `claude_desktop_config.json` takes the same `mcpServers` block as Cursor above.

<details>
<summary>Running from source</summary>

```sh
git clone https://github.com/afurm/rails-agent-kit
cd rails-agent-kit && bundle install
BUNDLE_GEMFILE=$PWD/Gemfile bundle exec rails-agent-kit --root /path/to/your/rails/app
```

</details>

`rails_routes` runs the app's `bin/rails` with Bundler's environment cleared, so your app uses its own Gemfile,
not rails-agent-kit's.

## Agent skill: Rails 8 conventions

The gem bundles a [Cursor skill](https://cursor.com/docs/skills),
[`skills/rails-8-conventions/SKILL.md`](skills/rails-8-conventions/SKILL.md). It tells the agent to check
`rails_schema`, `rails_routes` and `Gemfile.lock` before it edits code, then follow Rails 8 defaults:
`params.expect`, the built-in authentication generator, `rate_limit`, Solid Queue/Cache/Cable, Hotwire with
importmap/Propshaft, reversible migrations, and tests in the framework the app already uses. It also covers a
paired Next.js frontend. Install it into your app:

```sh
rails-agent-kit install-skills --root /path/to/your/rails/app                 # -> .cursor/skills/rails-8-conventions/SKILL.md
rails-agent-kit install-skills --root /path/to/your/rails/app --agent claude  # -> .claude/skills/...
```

Running it again is safe. It won't overwrite a skill you've edited unless you pass `--force`.

## Development

```sh
bundle install
bundle exec rake test
```

Tests use small fixture apps in `test/fixtures` (a `schema.rb`, a `structure.sql`, captured `rails routes`
output and a stand-in `bin/rails`), plus an end-to-end test that drives `exe/rails-agent-kit` over stdio JSON-RPC.

## License

MIT — see [LICENSE](LICENSE).
