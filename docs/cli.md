---
title: CLI reference
nav_order: 4
---

# CLI reference

```text
rails-agent-kit [--root PATH] [--routes-file FILE]       # start the MCP server on stdio
rails-agent-kit init [--root PATH] [--agent LIST] [--dry-run] [--force] [--no-skills]
rails-agent-kit install-skills [--root PATH] [--agent AGENT] [--force] [SKILL...]
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

Connects your agents to rails-agent-kit in one step:

| Agent | What `init` does |
| --- | --- |
| `cursor` | Writes `.cursor/mcp.json` (`mcpServers`, root `${workspaceFolder}`) and installs skills to `.cursor/skills/` |
| `claude` | Writes `.mcp.json` (`mcpServers`, root `.`) and installs skills to `.claude/skills/` |
| `vscode` | Writes `.vscode/mcp.json` (`servers`, root `${workspaceFolder}`) |
| `codex` | Adds the skills to `AGENTS.md` (a managed block) and prints a `[mcp_servers.rails-agent-kit]` block for `~/.codex/config.toml`. That's a global file, so `init` doesn't edit it |

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
| `--no-skills` | Only write the MCP config (no skills, no `AGENTS.md` block) |

## `install-skills`

Installs the bundled skills into the app. With no `SKILL` arguments it installs all bundled skills (today,
`rails-8-conventions`).

| `--agent` | Writes |
| --- | --- |
| `cursor` (default) | `.cursor/skills/<name>/SKILL.md` |
| `claude` | `.claude/skills/<name>/SKILL.md` |
| `codex` | A managed block in `AGENTS.md` |
| `copilot` | A managed block in `.github/copilot-instructions.md` |
| `gemini` | A managed block in `GEMINI.md` |

| Option | Purpose |
| --- | --- |
| `--root PATH` | Rails app root (default: the current directory) |
| `--agent AGENT` | `cursor` (default), `claude`, `codex`, `copilot` or `gemini`. An unknown name exits with status 64 |
| `--force` | Overwrite skill files you've edited locally |

It's safe to run again. Each path is reported as created, added, unchanged, updated or skipped.

- **Skill files** (`cursor`, `claude`) are copies of the bundled `SKILL.md`. A copy you've edited is skipped unless
  you pass `--force`.
- **Instruction files** (`codex`, `copilot`, `gemini`) get the skills' text, without front matter and with
  headings one level deeper, between `<!-- rails-agent-kit:start -->` and `<!-- rails-agent-kit:end -->`. A file
  without the block gets it appended (`added`), an outdated block is replaced (`updated`), and nothing outside the
  markers changes. A file with a start marker but no end marker is skipped.

See [Supported agents](agents) for which agents read which file.
