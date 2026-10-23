---
title: Agent skill
nav_order: 5
---

# Agent skill: Rails 8 conventions

[`skills/rails-8-conventions/SKILL.md`](https://github.com/afurm/rails-agent-kit/blob/main/skills/rails-8-conventions/SKILL.md)
is an [Agent Skill](https://cursor.com/docs/skills): a Markdown file with front matter that Cursor and Claude
Code load when the agent works on matching files (`app/**`, `config/**`, `db/**`, `lib/**`, `test/**`,
`spec/**`, `Gemfile`).

It tells the agent to:

- **check the facts first:** call `rails_schema` before it writes a model attribute, query, validation,
  fixture or migration; call `rails_routes` before it uses a `*_path` / `*_url` helper; read `Gemfile.lock`
  before it picks a library; and copy the structure of nearby files;
- **follow the Rails 8 defaults** unless the Gemfile says otherwise: `params.expect`, the built-in authentication
  generator, `rate_limit`, Solid Queue / Cache / Cable, Hotwire with importmap and Propshaft;
- write **reversible migrations**, and tests in the framework the app already uses;
- handle a **paired Next.js frontend** when there is one.

Without the MCP server, the skill falls back to reading `db/schema.rb`, `config/routes.rb` or running
`bin/rails routes -g`.

## Install

```sh
rails-agent-kit install-skills --root /path/to/your/rails/app                  # .cursor/skills/
rails-agent-kit install-skills --root /path/to/your/rails/app --agent claude   # .claude/skills/
rails-agent-kit install-skills --root /path/to/your/rails/app --agent codex    # AGENTS.md
rails-agent-kit install-skills --root /path/to/your/rails/app --agent copilot  # .github/copilot-instructions.md
rails-agent-kit install-skills --root /path/to/your/rails/app --agent gemini   # GEMINI.md
```

[Supported agents](agents) lists which agent reads which file.

See the [CLI reference](cli#install-skills) for options. On Rails 7.x the tools work the same, but some skill
advice (such as `params.expect` and the Solid Queue defaults) won't apply.
