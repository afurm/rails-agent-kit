---
title: CLI reference
nav_order: 4
---

# CLI reference

```text
rails-agent-kit [--root PATH] [--routes-file FILE]       # start the MCP server on stdio
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
