# rails-agent-kit

A tiny [Model Context Protocol](https://modelcontextprotocol.io) server that gives coding agents
(Cursor, Claude Code, …) **ground truth about your Rails app**: its database schema and its routes.

> Status: early scaffold (v0.1.0). Not published to RubyGems yet — run it from source.

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

From source (today):

```sh
git clone https://github.com/afurm/rails-agent-kit
cd rails-agent-kit
bundle install
# try it against an app:
BUNDLE_GEMFILE=$PWD/Gemfile bundle exec rails-agent-kit --root /path/to/your/rails/app
```

Once released (not yet): `gem install rails-agent-kit`.

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

Replace the paths with absolute paths on your machine.

**Cursor** — `.cursor/mcp.json` in your Rails app (or `~/.cursor/mcp.json`):

```json
{
  "mcpServers": {
    "rails-agent-kit": {
      "command": "bundle",
      "args": ["exec", "rails-agent-kit", "--root", "/path/to/your/rails/app"],
      "env": { "BUNDLE_GEMFILE": "/path/to/rails-agent-kit/Gemfile" }
    }
  }
}
```

**Claude Code**:

```sh
claude mcp add rails-agent-kit \
  -e BUNDLE_GEMFILE=/path/to/rails-agent-kit/Gemfile \
  -- bundle exec rails-agent-kit --root /path/to/your/rails/app
```

**Claude Desktop** — `claude_desktop_config.json` uses the same `mcpServers` block as Cursor above.

`rails_routes` runs the app's `bin/rails` with Bundler's environment cleared, so your app uses its own Gemfile,
not rails-agent-kit's.

## Development

```sh
bundle install
bundle exec rake test
```

Tests use small fixture apps in `test/fixtures` (a `schema.rb`, a `structure.sql`, captured `rails routes`
output and a stand-in `bin/rails`), plus an end-to-end test that drives `exe/rails-agent-kit` over stdio JSON-RPC.

## License

MIT — see [LICENSE](LICENSE).
