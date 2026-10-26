# Parser corpus

Real `db/schema.rb` files and `bin/rails routes --expanded` output that `test/corpus_test.rb` checks the parsers
against. Expected counts are never written by hand: they come from the booted app or from PostgreSQL.

## `apps/`

One directory per Rails version and database, created by [`script/corpus/generate_apps`](../../script/corpus/generate_apps)
with `rails new` and a few generators: Devise, the Rails 8 authentication generator (8.0 and later), scaffolds
(including a namespaced one), Active Storage and Action Text, a mounted engine, Sidekiq::Web and a Rack app. A
migration from [`script/corpus/templates/`](../../script/corpus/templates) adds the constructs the parser has to
handle: enums, virtual columns, check and exclusion constraints, composite primary keys, a second schema and
SQLite full-text search tables.

| File | What it is |
| --- | --- |
| `schema.rb` | `db/schema.rb` as Rails dumped it |
| `routes_expanded.txt` | `bin/rails routes --expanded`, with the app path removed from source locations |
| `expected.json` | Tables, per-table column counts and route counts, read from the booted app |

These files are generated from Rails' own templates (MIT).

## `external/`

Large open-source schemas. They're licensed AGPL-3.0, so they aren't committed here:
[`external.json`](external.json) pins each to a commit and a SHA-256, and
[`script/corpus/fetch_external`](../../script/corpus/fetch_external) downloads them into `tmp/corpus/external/`.
`external/<name>.expected.json` holds the tables and column counts PostgreSQL reported after loading the schema
with [`script/corpus/load_schema.rb`](../../script/corpus/load_schema.rb).

| Name | Source | License |
| --- | --- | --- |
| `mastodon` | [mastodon/mastodon](https://github.com/mastodon/mastodon) `db/schema.rb` | AGPL-3.0 |
| `forem` | [forem/forem](https://github.com/forem/forem) `db/schema.rb` | AGPL-3.0 |

## Regenerating

```sh
# Generated apps: needs Rails 7.2, 8.0 and 8.1 installed and a local PostgreSQL.
RUBY_3_4=~/.local/share/mise/installs/ruby/3.4/bin script/corpus/generate_apps

# External schemas: re-pin to the latest commit, download, and recount in PostgreSQL.
script/corpus/fetch_external --pin
ruby script/corpus/load_schema.rb tmp/corpus/external/mastodon.schema.rb > test/corpus/external/mastodon.expected.json
```
