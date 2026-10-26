# Roadmap

These are plans, not promises. Nothing here exists yet unless it's listed in [CHANGELOG.md](CHANGELOG.md).
Priorities change with user feedback, so [open an issue](https://github.com/afurm/rails-agent-kit/issues) if
something matters to you.

## Next

- **`structure.sql`:** foreign keys, constraints and enums, tested against large open-source schemas.
- **Multi-database apps:** the Solid Queue/Cache/Cable schemas and extra databases from `database.yml`.

## Later

- New tools: `rails_models` (associations, validations, enums and scopes,
  checked against the schema), `rails_jobs`, `rails_migrations`.
- `rails-agent-kit doctor` for setup diagnostics, cached routes, and a static routes fallback when the app can't boot.
- More skills (testing, safe migrations, Hotwire, security review) and a Claude Code plugin.
- MCP resources and prompts. Listing in the MCP Registry, plus automated releases.
- For paired Next.js apps: TypeScript types generated from the Rails API.
