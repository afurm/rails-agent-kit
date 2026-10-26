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

`main` is protected by a repository ruleset. **Nobody pushes to `main` directly, maintainer included.** Every
change goes through a pull request:

1. **Branch.** Outside contributors **fork** the repository first. Create a topic branch from an up-to-date
   `main`, named `<type>/<short-description>`, where type is one of `feat`, `fix`, `docs`, `chore`, `ci`,
   `release` (e.g. `fix/schema-check-constraints`, `feat/init-command`). Use lowercase words separated by
   hyphens.
2. **Change.** Make your change **with tests**, and run the full suite (below).
3. **Pull request.** Open a PR against `main` and fill in the template.
4. **Checks.** These must pass: `Ruby 3.2`, `Ruby 3.3`, `Ruby 3.4` and `Ruby 4.0`. `ruby-head` runs but is
   allowed to fail. The branch must be **up to date with `main`** before merging, so rebase if `main` has moved.
   All review threads must be resolved.
5. **Merge.** PRs are **squash-merged**, so the PR title becomes the commit subject on `main`. Write it like a
   commit subject. The PR branch is deleted after merge. Pull requests from outside contributors are reviewed
   and merged only by the maintainer ([@afurm](https://github.com/afurm)). Expect feedback; small, focused PRs
   get merged fastest.

The ruleset also blocks force-pushes and deletion of `main`, and nobody can bypass it.

For anything larger than a bug fix (a new tool, a CLI command, or a change to tool output shape), please open an
issue first so we can agree on the design before you write code.

### Does it belong in rails-agent-kit?

rails-agent-kit gives agents facts about a Rails app that they would otherwise guess. A good fit:

- reads something the app already defines (schema, routes, models, config) and returns it compactly;
- stays **read-only**, never touches the app's database, and avoids booting the app where a static read works;
- helps most Rails apps, not one app's setup.

Likely a no: tools that write files or run migrations, wrappers around services outside the app, and
features that work for only one MCP client when a standard MCP feature would do.

Use whatever tools you like to write your change. You're responsible for every line you submit, so make sure
you understand it and can answer questions about it.

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

To preview the docs site (`docs/`, Jekyll with Just the Docs):

```sh
cd docs && bundle install && bundle exec jekyll serve   # http://localhost:4000/rails-agent-kit/
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
| `docs/` | The documentation site, deployed to GitHub Pages from `main` |
| `test/fixtures/` | Small fixture apps: `schema.rb`, `structure.sql`, captured routes, a stub `bin/rails` |
| `test/corpus/` | Real schemas and routes from generated apps and open-source projects, with expected counts ([README](test/corpus/README.md)) |
| `script/corpus/` | Regenerates and fetches the corpus |

## Tests

- Every behaviour change needs a test. Parser fixes should add a minimal fixture under `test/fixtures/`.
- `test/corpus_test.rb` compares the parsers with real schemas and routes. Run `script/corpus/fetch_external`
  once to include the Mastodon and Forem schemas locally; without them those tests are skipped (CI always runs
  them).
- Tests use Minitest, run offline, and never boot a real Rails app. Use the stub `bin/rails` and the captured
  routes output instead.
- `test/server_test.rb` drives `exe/rails-agent-kit` over stdio JSON-RPC end to end. Extend it when you add or
  change a tool.
- `test/skills_test.rb` validates skill front-matter and checks that every MCP tool a skill mentions actually exists.

CI runs the suite on Ruby 3.2, 3.3, 3.4 and 4.0, plus `ruby-head` (allowed to fail).

## Style

- Follow the style of the surrounding code: `# frozen_string_literal: true`, double-quoted strings, two-space
  indentation, small methods, and no new runtime dependencies without discussion.
- Tools must stay **read-only** and must never connect to the app's database.
- Keep tool output compact and stable. Changing the output shape is a user-visible change and goes in the changelog.
- Skills: write instructions in the imperative, keep them short, and name tools in backticks
  (`` `rails_schema` ``) so the tests can check them.

## Commits and pull requests

- **Titles say what changes for the user**, in the imperative, as a plain sentence under about 72 characters:
  "Parse check constraints in structure.sql", "Return a compact schema overview by default". No `feat:` or
  `Docs:` prefixes; the label carries the type. PRs are squash-merged, so the title becomes the commit subject
  on `main`.
- **Descriptions explain the problem and the fix.** Fill in the [template](.github/PULL_REQUEST_TEMPLATE.md):
  what was wrong or missing, what the change does (with example tool output when the output changes), and how
  you tested it. Reference issues as `Fixes #123`.
- Keep one logical change per PR. Rebase on `main` rather than merging `main` into your branch. Force-pushing
  your own PR branch after a rebase is fine. `main` itself can never be force-pushed.
- Add an entry under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md) for user-visible changes, in the style
  described in [RELEASING.md](RELEASING.md#writing-the-changelog): a bold outcome sentence, the details, then
  `By @you. (#PR)`.
- The maintainer applies a label (`feature`, `fix`, `docs`, `internal`, `breaking-change`).

## Releases

Releases follow [Semantic Versioning](https://semver.org/). Before 1.0, minor versions may include breaking
changes, and these are called out in the changelog. The maintainer cuts releases through a release PR and a
version tag that triggers automated publishing; see [RELEASING.md](RELEASING.md).
