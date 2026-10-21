---
title: CLI reference
nav_order: 4
---

# CLI reference

```text
rails-agent-kit [--root PATH] [--routes-file FILE]       # start the MCP server on stdio
rails-agent-kit init [--root PATH] [--agent LIST] [--dry-run] [--force] [--no-skills]
rails-agent-kit install-skills [--root PATH] [--agent cursor|claude] [--force] [SKILL...]
rails-agent-kit --version
```

## Server

Your MCP client starts the server. You don't run it by hand, except to check that it starts.

| Option / env var | Purpose |
| --- | --- |
| `--root PATH` | Rails app root (default: the current directory) |
| `--routes-file FILE` | Use a saved `bin/rails routes --expanded` dump instead of booting the app |
| `RAILS_AGENT_KIT_ROUTES_TIMEOUT` | Seconds to wait for `bin/rails routes` (default `60`) |
| `RAILS_AGENT_KIT_ROUTES_COMMAND` | Override the routes command, e.g. `"docker compose exec -T web bin/rails routes --expanded"`. Runs in `--root` |

## `init`

On `main`, not yet released. Connects your agents to rails-agent-kit in one step:

| Agent | What `init` does |
| --- | --- |
| `cursor` | Writes `.cursor/mcp.json` (`mcpServers`, root `${workspaceFolder}`) and installs skills to `.cursor/skills/` |
| `claude` | Writes `.mcp.json` (`mcpServers`, root `.`) and installs skills to `.claude/skills/` |
| `vscode` | Writes `.vscode/mcp.json` (`servers`, root `${workspaceFolder}`) |
| `codex` | Prints a `[mcp_servers.rails-agent-kit]` block for `~/.codex/config.toml`. It's a global file, so `init` doesn't edit it |

If the app's `Gemfile` or `Gemfile.lock` includes rails-agent-kit, the config runs `bundle exec rails-agent-kit`
(with `BUNDLE_GEMFILE` where the client supports `${workspaceFolder}`). Otherwise it runs the installed
`rails-agent-kit` executable.

Existing config files keep their other servers and settings. Each file is reported as created, added, unchanged,
updated or skipped. A rails-agent-kit entry you've edited (for example, to add `--routes-file`) is skipped unless
you pass `--force`. A file that isn't valid JSON is left untouched, and `init` exits with status 65.

| Option | Purpose |
| --- | --- |
| `--root PATH` | Rails app root (default: the current directory) |
| `--agent LIST` | Comma-separated `cursor`, `claude`, `vscode`, `codex`, or `all` (default). An unknown name exits with status 64 |
| `--dry-run` | Show what would change without writing anything |
| `--force` | Replace a rails-agent-kit entry or skill you've edited |
| `--no-skills` | Only write the MCP config |

## `install-skills`

Copies the bundled skills into the app: `.cursor/skills/<name>/SKILL.md` by default, or
`.claude/skills/<name>/SKILL.md` with `--agent claude`. With no `SKILL` arguments it installs all bundled
skills (today, `rails-8-conventions`).

| Option | Purpose |
| --- | --- |
| `--root PATH` | Rails app root (default: the current directory) |
| `--agent AGENT` | `cursor` (default) or `claude` |
| `--force` | Overwrite skills you've edited locally |

It's safe to run again. Each skill is reported as created, unchanged, updated, or skipped. A skill you've edited
is skipped unless you pass `--force`.
