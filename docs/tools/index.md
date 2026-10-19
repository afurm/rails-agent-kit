---
title: Tools
nav_order: 3
has_children: true
permalink: /tools/
---

# Tools

rails-agent-kit exposes two MCP tools. Both are read-only (marked with `readOnlyHint`) and return JSON as a
single text content block. Responses are compact (single-line) JSON; the examples on these pages are
pretty-printed.

| Tool | What it returns | Boots the app? |
| --- | --- | --- |
| [`rails_schema`](rails-schema) | Tables, columns, indexes and foreign keys | **No.** Parses `db/schema.rb` statically, or `db/structure.sql` on a best-effort basis |
| [`rails_routes`](rails-routes) | Each route's name, verb, path, `controller#action` and source location | **Yes.** Runs `bin/rails routes --expanded`, unless you pass a saved dump |

The server also sends MCP `instructions` that tell the agent to check these tools before guessing model
attributes or URL helpers.
