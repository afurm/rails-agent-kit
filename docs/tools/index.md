---
title: Tools
nav_order: 3
has_children: true
permalink: /tools/
---

# Tools

rails-agent-kit exposes three MCP tools. All are read-only (marked with `readOnlyHint`) and return JSON as a
single text content block. Responses are compact (single-line) JSON; the examples on these pages are
pretty-printed.

| Tool | What it returns | Boots the app? |
| --- | --- | --- |
| [`rails_project_info`](rails-project-info) | Rails and Ruby versions, database, test framework, auth, jobs, frontend, deploy tools and where things live | **No.** Reads `Gemfile.lock` and config files |
| [`rails_schema`](rails-schema) | Tables, columns, indexes and foreign keys | **No.** Parses `db/schema.rb` statically, or `db/structure.sql` on a best-effort basis |
| [`rails_routes`](rails-routes) | Each route's name, verb, path, `controller#action` and source location | **Yes.** Runs `bin/rails routes --expanded`, unless you pass a saved dump |

The server also sends MCP `instructions` that tell the agent to call `rails_project_info` first and to check
these tools before guessing model attributes, URL helpers or libraries.
