# frozen_string_literal: true

require_relative "test_helper"

class SchemaParserTest < Minitest::Test
  include FixtureHelpers

  def setup
    @result = RailsAgentKit::SchemaParser.parse_file(fixture_path("blog_app", "db", "schema.rb"))
  end

  def table(name)
    @result.tables.find { |t| t[:name] == name } || flunk("missing table #{name}")
  end

  def column(table_name, col)
    table(table_name)[:columns].find { |c| c[:name] == col } || flunk("missing column #{table_name}.#{col}")
  end

  def test_version_and_extensions
    assert_equal "20261001120000", @result.version
    assert_equal ["pg_catalog.plpgsql"], @result.extensions
  end

  def test_tables
    assert_equal %w[comments posts posts_tags users], @result.tables.map { |t| t[:name] }
  end

  def test_primary_keys
    assert_equal "id", table("posts")[:primary_key]
    assert_equal({ name: "id", type: "bigint", null: false, primary_key: true }, column("posts", "id"))
    assert_nil table("posts_tags")[:primary_key]
    assert_equal "uuid", column("users", "id")[:type]
  end

  def test_column_options
    assert_equal({ name: "title", type: "string", null: false, limit: 200 }, column("posts", "title"))
    assert_equal({ name: "body", type: "text", null: true }, column("posts", "body"))
    assert_equal 0, column("posts", "status")[:default]
    assert_equal [3, 1], column("posts", "rating").values_at(:precision, :scale)
    assert_equal [[], true], column("posts", "tags").values_at(:default, :array)
    assert_equal '-> { "CURRENT_TIMESTAMP" }', column("posts", "created_at")[:default]
    assert_equal "", column("users", "email")[:default]
    assert_equal false, column("users", "admin")[:default]
    assert_equal "{}", column("users", "settings")[:default]
  end

  def test_comments_with_hash_and_commas_are_kept
    assert_equal "Shown publicly, may contain # signs", column("users", "display_name")[:comment]
    assert_equal "People who can log in", table("users")[:comment]
  end

  def test_indexes
    idx = table("posts")[:indexes]
    assert_equal 2, idx.size
    assert_equal({ table: "posts", name: "index_posts_on_user_id_and_published_at", columns: %w[user_id published_at], unique: false }, idx[0])
    assert_equal true, idx[1][:unique]
    assert_equal "(status = 1)", idx[1][:where]
    assert_equal ["email"], table("users")[:indexes].first[:columns]
  end

  def test_foreign_keys
    assert_equal [
      { from_table: "comments", to_table: "posts", column: "post_id" },
      { from_table: "comments", to_table: "users", column: "user_id", on_delete: "cascade" },
      { from_table: "posts", to_table: "users", column: "user_id" }
    ], @result.foreign_keys
  end
end
