---
title: Compatibility
nav_order: 7
---

# Compatibility

| | Versions | Status |
| --- | --- | --- |
| Ruby | 3.2, 3.3, 3.4, 4.0 | Tested in CI (`ruby-head` runs too, allowed to fail) |
| Rails (`db/schema.rb` format) | 8.0 | Covered by test fixtures |
| Rails | 7.2, 8.1 | Expected to work, but not yet covered by CI |
| MCP clients | Cursor, Claude Code, Codex, Claude Desktop, or any stdio MCP client | See [Getting started](getting-started) |

The bundled skill targets Rails 8 conventions. On Rails 7.x the tools work the same, but some skill advice
won't apply.

Versions follow [Semantic Versioning](https://semver.org/). Before 1.0, a minor release may include breaking
changes, which the [changelog](https://github.com/afurm/rails-agent-kit/blob/main/CHANGELOG.md) calls out.
