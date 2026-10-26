---
title: rails_schema
parent: Tools
nav_order: 2
---

# `rails_schema`
{: .no_toc }

The app's database schema, read from `db/schema.rb` without booting the app or connecting to a database. If
there's no `db/schema.rb`, it falls back to `db/structure.sql`.

1. TOC
{:toc}

## Parameters

All parameters are optional.

| Parameter | Type | Description |
| --- | --- | --- |
| `table` | string or array | Table name(s) to return in full: one exact name, an array, or a comma-separated list |
| `search` | string | Case-insensitive substring matched against table and column names, e.g. `"email"` |
| `detail` | `"overview"` or `"full"` | `overview` is the default with no `table` or `search`; `full` is the default with `table` |

{: .note }
Since 0.2.0, calling `rails_schema` with no arguments returns the overview. In 0.1.0 it returned the full schema;
pass `detail: "full"` for that output.

## Overview (no arguments)

Agents usually start here. The answer lists every table with its column count, a non-default primary key and
the tables its foreign keys point to, so it stays small on large apps. On a generated 300-table schema it is
about 23 KB, where the full dump is over 1 MB.

```js
// rails_schema {}
{
  "source": "db/schema.rb",
  "version": "20261001120000",
  "detail": "overview",
  "table_count": 4,
  "hint": "This is an overview. Pass table: \"users\" (or an array of names) for columns, indexes and foreign keys, search: \"email\" to find tables and columns by name, or detail: \"full\" for the whole schema.",
  "tables": [
    { "name": "comments", "columns": 6, "references": ["posts", "users"] },
    { "name": "posts", "columns": 10, "references": ["users"] },
    { "name": "posts_tags", "columns": 2, "primary_key": false },
    { "name": "users", "columns": 7 }
  ]
}
```

## One or more tables

`table` returns full columns (name, type, `null`, and `default`, `limit`, `precision` and so on where set),
indexes and the foreign keys of the requested tables.

```js
// rails_schema { "table": "comments" }  (columns trimmed)
{
  "version": "20261001120000",
  "tables": [{
    "name": "comments",
    "primary_key": "id",
    "columns": [
      { "name": "id", "type": "bigint", "null": false, "primary_key": true },
      { "name": "post_id", "type": "bigint", "null": false },
      { "name": "body", "type": "text", "null": false }
    ],
    "indexes": [
      { "table": "comments", "name": "index_comments_on_post_id", "columns": ["post_id"], "unique": false }
    ]
  }],
  "foreign_keys": [
    { "from_table": "comments", "to_table": "posts", "column": "post_id" },
    { "from_table": "comments", "to_table": "users", "column": "user_id", "on_delete": "cascade" }
  ],
  "source": "db/schema.rb"
}
```

When some requested tables don't exist, the rest are returned and the unknown names are listed in
`missing_tables`. When none exist, the answer is an error with `available_tables`.

## Search

```js
// rails_schema { "search": "email" }
{
  "source": "db/schema.rb",
  "version": "20261001120000",
  "search": "email",
  "match_count": 1,
  "matches": [
    { "table": "users", "columns": [{ "name": "email", "type": "string", "null": false }] }
  ]
}
```

## What it understands

Besides tables, columns and indexes, the parser reads the constructs real schemas use:

| In `db/schema.rb` | In the answer |
| --- | --- |
| `create_enum` and `t.enum ..., enum_type:` | `enums` with their values; the column gets `enum_type` and `values` |
| `t.virtual ..., as:, stored:` | The column's real `type`, plus `virtual: true`, `as` and `stored` |
| `t.check_constraint`, `add_check_constraint` | `check_constraints` on the table (`expression`, `name`) |
| `t.exclusion_constraint`, `t.unique_constraint` | `exclusion_constraints` / `unique_constraints` on the table |
| `create_table ..., primary_key: ["a", "b"]` | `primary_key` is the array, and those columns have `primary_key: true` |
| `create_schema`, `create_table "reporting.totals"` | `schemas`; tables outside `public` keep their `schema.` prefix |
| Expression indexes (`t.index "lower(email)"`) | The expression as the index's only `columns` entry |
| scenic `create_view` (and `add_index` on a materialized view) | `views`, with `materialized` and `indexes` |
| SQLite `create_virtual_table` (full-text search) | A table with `virtual: "fts5"` |

Statements that span several lines and heredoc bodies are handled. It's checked against `rails new` apps on
Rails 7.2, 8.0 and 8.1 (SQLite and PostgreSQL) and against the Mastodon and Forem schemas, with table and column
counts compared to what the database reports.

### Warnings

The parser never drops a line silently. A line inside `create_table` it doesn't understand, or a top-level
statement it skips (a trigger, an `execute`), is listed in `warnings` with its line number, and the warnings
come with every answer, the overview included:

```js
"warnings": [
  {
    "line": 2387,
    "statement": "create_trigger(\"update_reading_list_document\", :generated => true, :compatibility => 1). on(\"articles\")...",
    "message": "skipped: only tables, indexes, constraints, foreign keys, enums and views are read"
  }
]
```

## Size limit

Any answer over 60 KB is replaced by the overview with `truncated: true` and a note on how to narrow the
request, so a single call can't flood the agent's context.

## `db/structure.sql`

Apps that use `config.active_record.schema_format = :sql` get a best-effort parse of `CREATE TABLE`
statements. The answer has `"source": "db/structure.sql"` and a note that column types are raw SQL. Foreign keys
and constraints aren't extracted from `structure.sql` yet.

## Errors

With neither `db/schema.rb` nor `db/structure.sql` under `--root`, the tool returns an MCP error result that
says where it looked.
