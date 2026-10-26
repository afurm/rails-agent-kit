---
title: Compatibility
nav_order: 8
---

# Compatibility

| | Versions | Status |
| --- | --- | --- |
| Ruby | 3.2, 3.3, 3.4, 4.0 | Tested in CI (`ruby-head` runs too, allowed to fail) |
| Rails | 7.2, 8.0, 8.1 | Schemas and `bin/rails routes --expanded` output of generated apps (SQLite and PostgreSQL) are tested in CI |
| Real-world schemas | Mastodon, Forem | Tested in CI against the table and column counts PostgreSQL reports |
| MCP clients | Cursor, Claude Code, Codex, Claude Desktop, or any stdio MCP client | See [Getting started](getting-started) |

The bundled skill targets Rails 8 conventions. On Rails 7.x the tools work the same, but some skill advice
won't apply.

Versions follow [Semantic Versioning](https://semver.org/). Before 1.0, a minor release may include breaking
changes, which the [changelog](https://github.com/afurm/rails-agent-kit/blob/main/CHANGELOG.md) calls out.
