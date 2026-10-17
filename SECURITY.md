# Security Policy

## Supported versions

rails-agent-kit is pre-1.0. Security fixes go into the latest released version only.

| Version | Supported |
| --- | --- |
| 0.1.x (latest) | Yes |
| older | No |

## Reporting a vulnerability

**Please don't open a public issue, discussion or pull request for security problems.**

Report it privately through GitHub's security advisories:
**[Report a vulnerability](https://github.com/afurm/rails-agent-kit/security/advisories/new)**
(the repository's *Security* tab, then *Report a vulnerability*).

Please include:

- the affected version, and how you run the server (MCP client, flags, env vars)
- steps to reproduce, or a proof of concept
- the impact you see (e.g. reading files outside `--root`, or running unexpected commands)

What to expect: an acknowledgement within 3 business days, and an initial assessment within 7. We'll then agree on
a fix and a disclosure timeline with you. With your permission, you'll be credited in the advisory and the
changelog.

## Scope notes

rails-agent-kit runs locally with your user's permissions. `rails_schema` reads files only. `rails_routes`
runs your app's `bin/rails routes --expanded` (or `RAILS_AGENT_KIT_ROUTES_COMMAND`, if you set it) inside
`--root`. Problems in scope include running commands beyond those, reading outside the app root, or
injection through tool arguments.
