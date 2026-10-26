# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "tmpdir"

# Schema constructs beyond plain tables and columns, taken from a real Rails 8.1 + PostgreSQL dump
# (test/corpus/apps/rails-8.1-postgresql) and from hand-written snippets for what generated apps rarely contain.
class SchemaConstructsTest < Minitest::Test
  PG_SCHEMA = File.expand_path("corpus/apps/rails-8.1-postgresql/schema.rb", __dir__)
  SQLITE_SCHEMA = File.expand_path("corpus/apps/rails-8.1-sqlite3/schema.rb", __dir__)

  def pg
    @pg ||= RailsAgentKit::SchemaParser.parse_file(PG_SCHEMA)
  end

  def table(result, name)
    result.tables.find { |t| t[:name] == name } || flunk("missing table #{name}")
  end

  def column(result, table_name, name)
    table(result, table_name)[:columns].find { |c| c[:name] == name } || flunk("missing #{table_name}.#{name}")
  end

  def parse(body)
    RailsAgentKit::SchemaParser.new(<<~RUBY).parse
      ActiveRecord::Schema[8.1].define(version: 2026_10_26_000000) do
      #{body.gsub(/^/, '  ')}
      end
    RUBY
  end

  def test_postgres_enums_and_enum_columns
    assert_equal [{ name: "order_status", values: %w[pending paid shipped] }], pg.enums
    status = column(pg, "orders", "status")
    assert_equal "enum", status[:type]
    assert_equal "order_status", status[:enum_type]
    assert_equal %w[pending paid shipped], status[:values]
    assert_equal "pending", status[:default]
  end

  def test_virtual_columns_keep_their_real_type
    total = column(pg, "orders", "total")
    assert_equal "decimal", total[:type]
    assert_equal true, total[:virtual]
    assert_equal true, total[:stored]
    assert_equal "(subtotal + tax)", total[:as]
  end

  def test_check_constraints_are_constraints_not_columns
    orders = table(pg, "orders")
    refute(orders[:columns].any? { |c| c[:type] == "check_constraint" })
    assert_equal [
      { expression: "subtotal >= 0::numeric", name: "subtotal_non_negative" },
      { expression: "tax >= 0::numeric", name: "tax_non_negative" }
    ], orders[:check_constraints]
  end

  def test_exclusion_constraints
    assert_equal [{ expression: "room_id WITH =, during WITH &&", name: "no_overlapping_bookings", using: "gist" }],
                 table(pg, "bookings")[:exclusion_constraints]
  end

  def test_composite_primary_keys
    items = table(pg, "order_items")
    assert_equal %w[order_id position], items[:primary_key]
    assert_equal [true, true, nil], items[:columns].map { |c| c[:primary_key] }
  end

  def test_uuid_primary_key_with_default
    assert_equal({ name: "id", type: "uuid", null: false, primary_key: true }, column(pg, "bookings", "id"))
  end

  def test_tables_without_primary_key
    assert_nil table(pg, "settings")[:primary_key]
    assert_equal %w[key value], table(pg, "settings")[:columns].map { |c| c[:name] }
  end

  def test_schemas_and_schema_qualified_tables
    assert_equal ["reporting"], pg.schemas
    assert_equal %w[id day total], table(pg, "reporting.daily_totals")[:columns].map { |c| c[:name] }
  end

  def test_escaped_string_defaults
    assert_equal "line one\nline two, with a comma # and a hash", column(pg, "orders", "notes")[:default]
  end

  def test_sqlite_virtual_tables
    result = RailsAgentKit::SchemaParser.parse_file(SQLITE_SCHEMA)
    search = table(result, "posts_search")
    assert_equal "fts5", search[:virtual]
    assert_equal %w[title body], search[:columns].map { |c| c[:name] }
  end

  def test_statements_spanning_several_lines
    result = parse(<<~RUBY)
      create_table "events",
                   id: :uuid,
                   comment: "Spans, several lines",
                   force: :cascade do |t|
        t.jsonb "payload", default: {
          "kind" => "unknown"
        }, null: false
        t.string "kinds", array: true, default: [
          "a", "b"
        ]
      end
    RUBY
    events = table(result, "events")
    assert_equal "Spans, several lines", events[:comment]
    assert_equal %w[id payload kinds], events[:columns].map { |c| c[:name] }
    assert_equal %w[a b], events[:columns].last[:default]
    assert_empty result.warnings
  end

  def test_expression_indexes
    result = parse(<<~RUBY)
      create_table "accounts", force: :cascade do |t|
        t.string "username"
        t.index "lower((username)::text), COALESCE(lower((domain)::text), ''::text)", name: "index_lower", unique: true
      end
      add_index "accounts", "to_tsvector('simple'::regconfig, (username)::text)", name: "index_tsv", using: :gin
    RUBY
    indexes = table(result, "accounts")[:indexes]
    assert_equal ["lower((username)::text), COALESCE(lower((domain)::text), ''::text)"], indexes[0][:columns]
    assert_equal true, indexes[0][:unique]
    assert_equal "gin", indexes[1][:using]
    assert_empty result.warnings
  end

  def test_views_and_their_indexes_with_heredoc_bodies
    result = parse(<<~RUBY)
      create_view "user_ips", sql_definition: <<-SQL
          SELECT users.id AS user_id
         FROM users;
        end
      SQL
      create_view "instances", materialized: true, sql_definition: <<-SQL
          SELECT domain FROM accounts;
      SQL
      add_index "instances", ["domain"], name: "index_instances_on_domain", unique: true
      create_table "after", force: :cascade do |t|
        t.string "name"
      end
    RUBY
    assert_equal [{ name: "user_ips" }, { name: "instances", materialized: true, indexes: [
      { table: "instances", name: "index_instances_on_domain", columns: ["domain"], unique: true }
    ] }], result.views
    assert_equal ["after"], result.tables.map { |t| t[:name] }
    assert_empty result.warnings
  end

  def test_unknown_lines_inside_create_table_are_warnings
    result = parse(<<~RUBY)
      create_table "posts", force: :cascade do |t|
        t.string "title"
        t.some_plugin_call
      end
    RUBY
    assert_equal %w[id title], table(result, "posts")[:columns].map { |c| c[:name] }
    assert_equal 1, result.warnings.size
    warning = result.warnings.first
    assert_equal 4, warning[:line]
    assert_equal "t.some_plugin_call", warning[:statement]
    assert_match(/inside create_table "posts"/, warning[:message])
  end

  def test_unknown_top_level_statements_are_warnings_and_their_blocks_are_skipped
    result = parse(<<~RUBY)
      create_trigger("touch_posts", generated: true).
          on("posts").
          before(:update) do
        <<-SQL_ACTIONS
          NEW.updated_at = now();
        SQL_ACTIONS
      end
      execute "SELECT 1"
      create_table "posts", force: :cascade do |t|
        t.string "title"
      end
    RUBY
    assert_equal ["posts"], result.tables.map { |t| t[:name] }
    assert_equal [2, 9], result.warnings.map { |w| w[:line] }
    assert result.warnings.first[:statement].start_with?("create_trigger(")
  end

  def test_warnings_reach_the_schema_tool
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "db"))
      File.write(File.join(root, "db", "schema.rb"), <<~RUBY)
        ActiveRecord::Schema[8.1].define(version: 1) do
          create_table "posts" do |t|
            t.mystery "x"
            t.unknown_call
          end
        end
      RUBY
      overview = RailsAgentKit::SchemaInspector.new(root).call
      assert_equal 1, overview[:warnings].size
      assert_equal "t.unknown_call", overview[:warnings].first[:statement]
    end
  end
end
