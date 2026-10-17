# Roadmap

These are plans, not promises. Nothing here exists yet unless it's listed in [CHANGELOG.md](CHANGELOG.md).
Priorities change with user feedback, so [open an issue](https://github.com/afurm/rails-agent-kit/issues) if
something matters to you.

## Next

- **`rails-agent-kit init`:** one command that writes MCP config for Cursor, Claude Code, VS Code and Codex,
  and installs skills.
- **Compact `rails_schema` output:** a table overview by default, plus `search` and multi-table lookups, so large
  schemas don't flood the agent's context.
- **Routes with the app's Ruby:** detect rbenv, asdf, mise or bundler, so `rails_routes` boots with the right Ruby.
- **Parser robustness:** test against real-world schemas and routes (`rails new` on 7.2–8.1, and large open-source apps).
- **Multi-database apps:** the Solid Queue/Cache/Cable schemas and extra databases from `database.yml`.
- **AGENTS.md output:** for Codex and other agents that read it, plus GitHub Copilot and Gemini CLI instruction files.

## Later

- New tools: `rails_project_info` (stack detection), `rails_models` (associations, validations, enums and scopes,
  checked against the schema), `rails_jobs`, `rails_migrations`.
- `rails-agent-kit doctor` for setup diagnostics, cached routes, and a static routes fallback when the app can't boot.
- More skills (testing, safe migrations, Hotwire, security review) and a Claude Code plugin.
- MCP resources and prompts. Listing in the MCP Registry, plus automated releases.
- For paired Next.js apps: TypeScript types generated from the Rails API.
