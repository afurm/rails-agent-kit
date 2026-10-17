# Contributing to rails-agent-kit

Thanks for helping! This guide covers how to report problems, propose changes and get a pull request merged.
By taking part you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Ways to contribute

- **Bugs:** open a [bug report](https://github.com/afurm/rails-agent-kit/issues/new?template=bug_report.yml).
  Include your Ruby and Rails versions, your MCP client, and the smallest `schema.rb` or `routes.rb` snippet
  that reproduces the problem. A parser bug with a failing fixture is the best possible report.
- **Ideas:** open a [feature request](https://github.com/afurm/rails-agent-kit/issues/new?template=feature_request.yml),
  or check the [roadmap](ROADMAP.md) first.
- **Questions:** use [GitHub Discussions](https://github.com/afurm/rails-agent-kit/discussions).
- **Security issues:** never report these in public issues. See [SECURITY.md](SECURITY.md).

## How changes get in

1. **Fork** the repository and create a topic branch from `main` (e.g. `fix/schema-check-constraints`).
2. Make your change **with tests**, and run the full suite (below).
3. Open a **pull request** against `main` and fill in the template.
4. CI must be green. The maintainer ([@afurm](https://github.com/afurm)) reviews every PR, and **only the
   maintainer merges**. Expect feedback; small, focused PRs get merged fastest.

For anything larger than a bug fix (a new tool, a CLI command, or a change to tool output shape), please open an
issue first so we can agree on the design before you write code.

## Development setup

You need Ruby 3.2 or newer and Bundler.

```sh
git clone https://github.com/<you>/rails-agent-kit && cd rails-agent-kit
bundle install
bundle exec rake test                      # full suite
bundle exec ruby -Itest test/routes_test.rb  # a single file
```

To try your working copy against a real app:

```sh
BUNDLE_GEMFILE=$PWD/Gemfile bundle exec exe/rails-agent-kit --root /path/to/a/rails/app
```

### Project layout

| Path | What lives there |
| --- | --- |
| `lib/rails_agent_kit/schema_parser.rb`, `structure_sql_parser.rb` | Static `schema.rb` / `structure.sql` parsers |
| `lib/rails_agent_kit/routes_*.rb` | Running `bin/rails routes --expanded` and parsing its output |
| `lib/rails_agent_kit/server.rb` | MCP server and tool definitions (official `mcp` gem) |
| `lib/rails_agent_kit/skill_installer.rb` | `install-skills` |
| `skills/<name>/SKILL.md` | Bundled agent skills (shipped in the gem) |
| `exe/rails-agent-kit` | CLI entry point |
| `test/fixtures/` | Small fixture apps: `schema.rb`, `structure.sql`, captured routes, a stub `bin/rails` |

## Tests

- Every behaviour change needs a test. Parser fixes should add a minimal fixture under `test/fixtures/`.
- Tests use Minitest, run offline, and never boot a real Rails app. Use the stub `bin/rails` and the captured
  routes output instead.
- `test/server_test.rb` drives `exe/rails-agent-kit` over stdio JSON-RPC end to end. Extend it when you add or
  change a tool.
- `test/skills_test.rb` validates skill front-matter and checks that every MCP tool a skill mentions actually exists.

CI runs the suite on Ruby 3.2, 3.3 and 3.4.

## Style

- Follow the style of the surrounding code: `# frozen_string_literal: true`, double-quoted strings, two-space
  indentation, small methods, and no new runtime dependencies without discussion.
- Tools must stay **read-only** and must never connect to the app's database.
- Keep tool output compact and stable. Changing the output shape is a user-visible change and goes in the changelog.
- Skills: write instructions in the imperative, keep them short, and name tools in backticks
  (`` `rails_schema` ``) so the tests can check them.

## Commits and pull requests

- Write commit subjects in the imperative and under about 72 characters, e.g. "Parse check constraints in
  schema.rb". Add a body explaining *why* when it isn't obvious. Reference issues as `Fixes #123`.
- Keep one logical change per PR. Rebase on `main` rather than merging `main` into your branch.
- Add an entry under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md) for user-visible changes
  (Added / Changed / Deprecated / Removed / Fixed / Security).
- The maintainer applies a label (`feature`, `fix`, `docs`, `internal`, `breaking-change`), which decides where
  the PR appears in the auto-generated release notes.

## Releases

Releases follow [Semantic Versioning](https://semver.org/). Before 1.0, minor versions may include breaking
changes, and these are called out in the changelog. The maintainer cuts releases; see [RELEASING.md](RELEASING.md).
