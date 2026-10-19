---
name: rails-8-conventions
description: Rails 8 conventions and a ground-truth-first workflow. Use when adding or changing models, migrations, controllers, routes, views, jobs, mailers or tests in a Rails 8 app, so changes follow the app's actual schema, routes and stack instead of guesses.
paths:
  - "app/**"
  - "config/**"
  - "db/**"
  - "lib/**"
  - "test/**"
  - "spec/**"
  - "Gemfile"
metadata:
  source: rails-agent-kit
---

# Rails 8 conventions

Follow the app as it is, not Rails as you remember it. Check the facts first, then
change the code the way this app already does things.

## 1. Check the facts before you edit

- **Schema:** call the `rails_schema` MCP tool before you write a model attribute, query,
  validation, fixture or migration. With no arguments it lists the tables; pass `table:`
  (one name or an array) for their columns, or `search:` to find a column by name. Without the
  tool, read `db/schema.rb` (or `db/structure.sql`). Never guess a column name, type,
  nullability or default.
- **Routes:** call the `rails_routes` MCP tool (pass `filter:`) before you use a
  `*_path`/`*_url` helper, link, form `url:` or redirect. Without it, read
  `config/routes.rb` or run `bin/rails routes -g <term>`.
- **Stack:** read `Gemfile.lock` before you pick a library. Use what the app already
  uses (RSpec or Minitest, Sidekiq or Solid Queue, Pundit, Devise or the built-in
  auth generator, importmap or jsbundling). Don't add a gem when the app or Rails
  already covers it.
- **Local patterns:** before you add a model, controller or job, open one or two
  nearby files and copy their structure: concerns, base classes, naming, and how
  they render and respond.

## 2. Rails 8 defaults (unless the Gemfile says otherwise)

- **Strong params:** use `params.expect(post: [:title, :body])` (Rails 8). It returns
  400 on a malformed payload instead of raising a 500. Use
  `params.require(...).permit(...)` only if the codebase still uses it.
- **Authentication:** `bin/rails generate authentication` gives you the `Session`
  model, the `Authentication` concern, `Current.user`, `allow_unauthenticated_access`
  and `require_authentication`. Use these when they're present. Don't add Devise
  alongside them.
- **Rate limiting:** `rate_limit to: 10, within: 3.minutes, only: :create` in the
  controller. You don't need Rack::Attack for simple cases.
- **Models:** `enum :status, { draft: 0, published: 1 }` (keyword-arg form),
  `normalizes :email, with: ->(e) { e.strip.downcase }`, `generates_token_for`,
  `has_secure_password`. Put validations in the model *and* constraints in the DB:
  `null: false`, unique indexes, foreign keys.
- **Background jobs:** Solid Queue is the default (`config/queue.yml`). Recurring
  work goes in `config/recurring.yml`, not cron. Inherit from `ApplicationJob`, pass
  records or ids (GlobalID), and make `perform` idempotent. Use `perform_later`.
  Call `perform_now` only in tests or consoles.
- **Cache and Cable:** Solid Cache and Solid Cable are database-backed and may use
  their own databases (`db/cache_schema.rb`, `db/queue_schema.rb`,
  `db/cable_schema.rb`). Don't move them to Redis on your own.
- **Frontend:** Hotwire is the default. Use Turbo Frames/Streams for partial updates
  and Stimulus controllers in `app/javascript/controllers`. Assets go through
  Propshaft, and JS through importmap (`bin/importmap pin <pkg>`) unless the app uses
  jsbundling. Don't add a SPA framework into `app/`.
- **Deploy:** Kamal 2 (`config/deploy.yml`) and Thruster. Secrets live in
  `config/credentials` or `.kamal/secrets`, never in code.

## 3. Migrations

- Generate them: `bin/rails generate migration AddPublishedAtToPosts published_at:datetime:index`.
  Never hand-pick a timestamp.
- Make them reversible (`change`, or `up`/`down`), and add indexes and foreign keys
  (`t.references :user, null: false, foreign_key: true`).
- Never edit a migration that has already run on a shared branch. Add a new one.
- Run `bin/rails db:migrate` and commit the updated `db/schema.rb` (or
  `structure.sql`) with the migration. After that, `rails_schema` is the source of
  truth.

## 4. Controllers, routes and views

- Prefer RESTful `resources` with the seven standard actions. When you need a custom
  action, add a nested resource or a new controller instead
  (`resource :publication, only: :create`).
- Keep controllers thin: load, authorize, call the model, respond. Make
  `before_action :set_post` match the existing style.
- Respond to `format.html` and `format.turbo_stream` when the app uses Turbo. On a
  failed form submit, render with `status: :unprocessable_entity`. Use
  `redirect_to ..., status: :see_other` after a destroy.
- Use the route helpers confirmed in step 1. Don't hard-code a URL string.

## 5. Tests

- Use the existing framework: `test/` (Minitest, fixtures) or `spec/` (RSpec,
  factories). Don't add a second one.
- Add or update a test with every behaviour change: model tests for validations and
  scopes, request/integration tests for endpoints, job tests for jobs.
- Run the narrowest test first (`bin/rails test test/models/post_test.rb`), then the
  suite (`bin/rails test`, or `bin/rails test:all` with system tests). Run
  `bin/rubocop` if it exists.

## 6. Paired Next.js frontend (if there is one)

If the Rails app is an API for a separate Next.js app (`config.api_only = true`, JSON
controllers, a sibling `web/` or `frontend/` directory):

- Treat JSON responses as a contract. Add fields rather than rename or remove them,
  and update the Next.js types and fetchers in the same change.
- Check `rails_routes` for the exact path and verb before you write a fetch call
  on the frontend.
- Keep CORS (`config/initializers/cors.rb`) and auth (cookie vs token) consistent
  with what the frontend already does.

## Before you finish

- [ ] Every column, table and route helper you used is confirmed by `rails_schema` or `rails_routes` (or the files behind them).
- [ ] Migrations are reversible and `db/schema.rb` is updated.
- [ ] Tests were added or updated, and they pass.
- [ ] You added no new gem or framework that the app's existing stack already covers.
