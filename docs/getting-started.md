---
title: Getting started
nav_order: 2
---

# Getting started
{: .no_toc }

1. TOC
{:toc}

## Install

```sh
gem install rails-agent-kit
```

or, inside your Rails app:

```sh
bundle add rails-agent-kit --group development
```

rails-agent-kit needs Ruby 3.2 or newer. It reads the app in the directory you pass with `--root`. In every
example below, replace `/path/to/your/rails/app` with the absolute path to your app.

## Connect your agent

### One command

On `main`, not yet released. From your app's root:

```sh
bundle add rails-agent-kit --group development
bundle exec rails-agent-kit init
```

`init` writes `.cursor/mcp.json`, `.mcp.json` (Claude Code) and `.vscode/mcp.json` with project-relative paths,
keeps any servers you already have, installs the Rails 8 skill for Cursor and Claude Code, and prints the
snippet for Codex's `~/.codex/config.toml`. See [`init`](cli#init) for the options. To set up a client by hand,
use the sections below.

### Cursor

`.cursor/mcp.json` in your app (or `~/.cursor/mcp.json`):

```json
{
  "mcpServers": {
    "rails-agent-kit": {
      "command": "rails-agent-kit",
      "args": ["--root", "/path/to/your/rails/app"]
    }
  }
}
```

### Claude Code

```sh
claude mcp add rails-agent-kit -- rails-agent-kit --root /path/to/your/rails/app
```

### Codex

```sh
codex mcp add rails-agent-kit -- rails-agent-kit --root /path/to/your/rails/app
```

or in `~/.codex/config.toml`:

```toml
[mcp_servers.rails-agent-kit]
command = "rails-agent-kit"
args = ["--root", "/path/to/your/rails/app"]
```

### Claude Desktop and other MCP clients

Any client that launches stdio MCP servers works. Claude Desktop's `claude_desktop_config.json` takes the same
`mcpServers` block as Cursor.

### Installed with `bundle add`

Run it through the app's bundle:

```json
{
  "mcpServers": {
    "rails-agent-kit": {
      "command": "bundle",
      "args": ["exec", "rails-agent-kit", "--root", "/path/to/your/rails/app"],
      "env": { "BUNDLE_GEMFILE": "/path/to/your/rails/app/Gemfile" }
    }
  }
}
```

```sh
claude mcp add rails-agent-kit -e BUNDLE_GEMFILE=/path/to/your/rails/app/Gemfile \
  -- bundle exec rails-agent-kit --root /path/to/your/rails/app
```

## Add the agent skill (optional)

```sh
rails-agent-kit install-skills --root /path/to/your/rails/app                 # Cursor
rails-agent-kit install-skills --root /path/to/your/rails/app --agent claude  # Claude Code
```

See [Agent skill](agent-skill) for what it does.

## Check it works

Ask your agent something like *"Which columns does the users table have?"* or *"What's the route helper for
creating a comment?"*. It should call `rails_schema` or `rails_routes` instead of guessing.

If routes come back with `routes_unavailable: true`, the app couldn't boot. See
[Routes without booting](tools/rails-routes#routes-without-booting).
