---
title: rails_project_info
parent: Tools
nav_order: 1
---

# `rails_project_info`
{: .no_toc }

What kind of Rails app this is, in one small answer: versions, database, test setup, auth, jobs, frontend and
deploy tools. It reads `Gemfile.lock` and a few config files, and never boots the app. Agents call it first, so
they pick the libraries and test style the app already uses.

1. TOC
{:toc}

## Parameters

None.

## Example

An app with RSpec, FactoryBot, Devise, Pundit and Sidekiq
([`test/fixtures/project_info/rspec_devise`](https://github.com/afurm/rails-agent-kit/tree/main/test/fixtures/project_info/rspec_devise)):

```js
// rails_project_info {}
{
  "rails": "8.1.4",
  "ruby": {
    "version": "4.0.7",
    "source": ".ruby-version"
  },
  "load_defaults": "8.1",
  "api_only": false,
  "database": {
    "adapter": "postgresql",
    "databases": {
      "production": [
        "primary",
        "cache",
        "queue",
        "cable"
      ]
    }
  },
  "test": {
    "framework": "rspec",
    "data": "factory_bot",
    "system": null
  },
  "auth": "devise",
  "authorization": "pundit",
  "jobs": "sidekiq",
  "cache": "solid_cache",
  "cable": "solid_cable",
  "frontend": {
    "js": "importmap",
    "assets": "propshaft",
    "hotwire": [
      "turbo",
      "stimulus"
    ],
    "css": "tailwind",
    "views": "view_component"
  },
  "serializers": "jbuilder",
  "graphql": false,
  "quality": [
    "rubocop-rails-omakase",
    "brakeman",
    "bundler-audit"
  ],
  "deploy": [
    "kamal",
    "docker",
    "procfile"
  ],
  "engines": [
    {
      "engine": "Sidekiq::Web",
      "at": "/sidekiq"
    }
  ],
  "gems": {
    "pagy": "43.8.1",
    "image_processing": "1.14.0"
  },
  "paths": {
    "tests": "spec",
    "factories": "spec/factories",
    "policies": "app/policies",
    "components": "app/components"
  },
  "sources": [
    "Gemfile.lock",
    ".ruby-version",
    "config/application.rb",
    "config/database.yml",
    "config/environments/production.rb",
    "config/cable.yml",
    "config/importmap.rb",
    "config/routes.rb"
  ]
}
```

The answer is about 1 KB on a typical app.

## Fields

Every value comes from a file in the app. When the files don't say, the value is `null`: the tool never guesses.
A field that names a library is a string, or an array when the app uses several.

| Field | Read from |
| --- | --- |
| `rails` | The `rails` (or `railties`) version in `Gemfile.lock` |
| `ruby` | `.ruby-version`, `.tool-versions`, `mise.toml`, the Gemfile `ruby` line or `Gemfile.lock`, with the file it came from |
| `load_defaults`, `api_only` | `config/application.rb` |
| `database` | `config/database.yml`: the adapter, and `databases` for each environment with several (multi-DB, Solid Cache/Queue/Cable) |
| `test` | `framework` (`rspec` or `minitest`, from `spec/rails_helper.rb` or `test/test_helper.rb`), `data` (`factory_bot`, `fabrication` or `fixtures`) and `system` (`capybara`) |
| `auth` | `rails_authentication` (the Rails 8 generator's `Authentication` concern and `Session` model), `devise`, `rodauth`, `sorcery` or `clearance` |
| `authorization` | `pundit`, `cancancan` or `action_policy` |
| `jobs` | `config.active_job.queue_adapter` in `production.rb` or `application.rb`; if it isn't set, the jobs gem in the Gemfile |
| `cache`, `cable` | `config.cache_store` in `production.rb`, and the production adapter in `config/cable.yml` |
| `frontend` | `js` (`importmap`, `jsbundling`, `vite`, ...), `assets` (`propshaft` or `sprockets`), `hotwire`, `css` (`tailwind`, ...) and `views` (`view_component` or `phlex`). `null` for API-only apps |
| `serializers`, `graphql` | `jbuilder`, `alba`, `blueprinter`, `active_model_serializers`, ...; whether the `graphql` gem is used |
| `quality`, `deploy` | Lint and security gems; `kamal`, `docker`, `procfile`, `fly`, `render` or `heroku` from their config files |
| `engines` | `mount` lines in `config/routes.rb` |
| `gems` | Notable gems the app depends on directly (pagination, auditing, search, payments, error tracking, ...) with their versions |
| `paths` | Where tests, factories, fixtures, policies, components, serializers, services and GraphQL types live |
| `sources` | The files the answer was read from |

Libraries come from the app's direct dependencies (the `DEPENDENCIES` section of `Gemfile.lock`), not gems
that other gems pull in. Without a `Gemfile.lock`, the gem lines of the `Gemfile` are used and versions are
`null`.

## Errors

Without a `Gemfile` or `config/application.rb` under `--root`, the tool returns an MCP error result saying the
directory doesn't look like a Rails app.
