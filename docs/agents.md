---
title: Supported agents
nav_order: 6
---

# Supported agents

The MCP server works with any client that can start a stdio MCP server. The bundled skill has one source,
[`skills/<name>/SKILL.md`](https://github.com/afurm/rails-agent-kit/tree/main/skills), and `install-skills`
installs it in each agent's own format:

| Agent | MCP config (`init`) | Skill (`install-skills --agent …`) |
| --- | --- | --- |
| Cursor | `.cursor/mcp.json` | `cursor`: `.cursor/skills/<name>/SKILL.md`. Cursor also reads `AGENTS.md` |
| Claude Code | `.mcp.json` | `claude`: `.claude/skills/<name>/SKILL.md` |
| Codex | Snippet for `~/.codex/config.toml` | `codex`: managed block in `AGENTS.md` |
| GitHub Copilot (VS Code) | `.vscode/mcp.json` | `copilot`: managed block in `.github/copilot-instructions.md`. Copilot also reads `AGENTS.md` |
| Gemini CLI | Add the server to `.gemini/settings.json` by hand | `gemini`: managed block in `GEMINI.md` |
| Windsurf, Zed and other `AGENTS.md` readers | See the client's MCP docs | `codex`: managed block in `AGENTS.md` |

## Managed blocks

`AGENTS.md`, `.github/copilot-instructions.md` and `GEMINI.md` usually hold your own project instructions, so
rails-agent-kit only writes between two markers:

```markdown
<!-- rails-agent-kit:start -->
...
<!-- rails-agent-kit:end -->
```

If the file has no block yet, it's appended at the end. Running `install-skills` again after a gem upgrade
replaces the block with the new version. Everything outside the markers stays as you wrote it. Inside the block,
the skill's front matter is removed and its headings move one level down, so they nest under your file's own
title.

## Windsurf

There's no separate Windsurf target. Windsurf reads `AGENTS.md`, so `--agent codex` already covers it, and a
second copy in `.windsurf/rules/` would only put the same text into the context twice.

## Using more than one agent

Each target is independent, so you can install several. Cursor and Copilot read both their own files and
`AGENTS.md`, so if your team uses them alongside Codex, the `AGENTS.md` block alone may be enough.
