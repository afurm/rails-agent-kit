---
title: Home
layout: home
nav_order: 1
description: Ground truth about your Rails app, for coding agents.
permalink: /
---

# Ground truth about your Rails app, for coding agents
{: .fs-9 }

A read-only [MCP](https://modelcontextprotocol.io) server that gives Cursor, Claude Code, Codex and other MCP
clients your app's real schema and routes, plus a Rails 8 skill that tells the agent to check them before it
writes code.
{: .fs-6 .fw-300 }

[Get started](getting-started){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-2 }
[View on GitHub](https://github.com/afurm/rails-agent-kit){: .btn .fs-5 .mb-4 .mb-md-0 }

---

## Look it up instead of guessing

Agents writing Rails code guess all the time. *Is it `user.full_name` or `user.name`? Is the column nullable?
Is the helper `post_comments_path` or `comments_path`?* Each wrong guess is broken code and another review
round. rails-agent-kit lets the agent ask your app.

- **[`rails_schema`](tools/rails-schema):** tables, columns, indexes and foreign keys from `db/schema.rb`,
  parsed statically. It never boots the app or connects to a database.
- **[`rails_routes`](tools/rails-routes):** every route with its name, verb, path, `controller#action` and
  source line, from your app's own `bin/rails routes --expanded`.
- **[Rails 8 conventions skill](agent-skill):** an Agent Skill for Cursor and Claude Code that tells the agent
  to call the tools before it edits code.
- **Read-only and local:** a stdio server your client starts. It doesn't listen on a network port.

## Two minutes to set up

```sh
gem install rails-agent-kit
claude mcp add rails-agent-kit -- rails-agent-kit --root /path/to/your/rails/app
```

That's Claude Code. [Getting started](getting-started) covers Cursor, Codex, Claude Desktop and running it
through your app's bundle.

## What the agent sees

A real answer for the small blog app in the test fixtures, pretty-printed and trimmed:

```js
// rails_routes { "filter": "comments" }
{
  "total": 7,
  "count": 2,
  "routes": [
    { "name": "post_comments", "verb": "POST", "path": "/posts/:post_id/comments(.:format)",
      "controller_action": "comments#create", "source_location": "config/routes.rb:3" },
    { "name": "post_comment", "verb": "DELETE", "path": "/posts/:post_id/comments/:id(.:format)",
      "controller_action": "comments#destroy", "source_location": "config/routes.rb:3" }
  ]
}
```

{: .note }
rails-agent-kit is early (v0.1.0), and the API may change before 1.0. Pages mark features that are on `main`
but not yet released.
