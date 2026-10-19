# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "tmpdir"
require "fileutils"

# AND-110: the default rails_schema answer must stay small on big apps.
class SchemaOverviewTest < Minitest::Test
  include FixtureHelpers

  # Writes a schema.rb shaped like a large production app: `count` tables with 8-30 columns,
  # a couple of indexes each, and a foreign key to the previous table.
  def with_large_schema(count = 300)
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "db"))
      File.write(File.join(dir, "db", "schema.rb"), large_schema(count))
      yield dir
    end
  end

  def large_schema(count)
    out = +"ActiveRecord::Schema[8.1].define(version: 2026_10_19_000000) do\n"
    count.times do |i|
      name = format("table_%03d_records", i)
      out << %(  create_table "#{name}", force: :cascade do |t|\n)
      out << %(    t.bigint "table_#{format('%03d', i - 1)}_record_id"\n) if i.positive?
      (8 + (i % 23)).times do |c|
        out << %(    t.string "attribute_number_#{c}", limit: 255, default: "", null: false\n)
      end
      out << %(    t.string "contact_email"\n) if (i % 50).zero?
      out << %(    t.datetime "created_at", null: false\n    t.datetime "updated_at", null: false\n)
      out << %(    t.index ["attribute_number_0"], name: "index_#{name}_on_attribute_number_0", unique: true\n)
      out << %(    t.index ["created_at"], name: "index_#{name}_on_created_at"\n)
      out << "  end\n\n"
    end
    (1...count).each do |i|
      out << %(  add_foreign_key "#{format('table_%03d_records', i)}", "#{format('table_%03d_records', i - 1)}", ) +
             %(column: "table_#{format('%03d', i - 1)}_record_id"\n)
    end
    out << "end\n"
  end

  def inspector(root, **opts)
    RailsAgentKit::SchemaInspector.new(root, **opts)
  end

  def bytes(data)
    JSON.generate(data).bytesize
  end

  def test_overview_is_the_default_and_is_small_on_a_300_table_schema
    with_large_schema do |dir|
      full = inspector(dir).call(detail: "full")
      overview = inspector(dir).call

      assert_equal "overview", overview[:detail]
      assert_equal 300, overview[:table_count]
      assert_equal 300, overview[:tables].size
      # Worst case: every table has a foreign key and a 17-character name. Real apps come in lower.
      assert_operator bytes(overview), :<, 24_000, "overview is #{bytes(overview)} bytes"
      assert_operator JSON.pretty_generate(RailsAgentKit::SchemaInspector.new(dir, max_bytes: Float::INFINITY)
                                             .call(detail: "full")).bytesize, :>, 500_000
      assert full[:truncated], "full output of a 300-table schema should hit the size guard"

      t1 = overview[:tables].find { |t| t[:name] == "table_001_records" }
      assert_equal({ name: "table_001_records", columns: 13, references: ["table_000_records"] }, t1)
      assert_match(/table:/, overview[:hint])
    end
  end

  def test_overview_on_small_schema
    result = inspector(fixture_path("blog_app")).call
    assert_equal "db/schema.rb", result[:source]
    assert_equal "20261001120000", result[:version]
    by_name = result[:tables].to_h { |t| [t[:name], t] }

    assert_equal %w[comments posts posts_tags users], by_name.keys
    assert_equal 6, by_name["comments"][:columns]
    assert_equal %w[posts users], by_name["comments"][:references]
    assert_equal false, by_name["posts_tags"][:primary_key]
    refute by_name["users"].key?(:primary_key), "default primary key \"id\" is omitted"
    refute by_name["users"].key?(:references)
  end

  def test_overview_from_structure_sql
    result = inspector(fixture_path("sql_app")).call
    assert_equal "db/structure.sql", result[:source]
    assert_match(/best-effort/, result[:note])
    assert_equal({ name: "accounts", columns: 4 }, result[:tables].find { |t| t[:name] == "accounts" })
  end

  def test_full_detail_keeps_the_old_shape
    result = inspector(fixture_path("blog_app")).call(detail: "full")
    assert_equal 4, result[:tables].size
    assert_equal 3, result[:foreign_keys].size
    assert result[:tables].all? { |t| t[:columns].is_a?(Array) && t.key?(:indexes) }
    refute result.key?(:truncated)
  end

  def test_table_accepts_an_array_and_a_comma_separated_list
    [%w[posts users], "posts, users"].each do |arg|
      result = inspector(fixture_path("blog_app")).call(table: arg)
      assert_equal %w[posts users], result[:tables].map { |t| t[:name] }
      assert(result[:tables].all? { |t| t[:columns].first.key?(:type) })
      assert_equal 3, result[:foreign_keys].size
      refute result.key?(:missing_tables)
    end
  end

  def test_table_array_with_some_unknown_names
    result = inspector(fixture_path("blog_app")).call(table: %w[posts nope])
    assert_equal ["posts"], result[:tables].map { |t| t[:name] }
    assert_equal ["nope"], result[:missing_tables]
    refute result.key?(:error)
  end

  def test_table_array_with_only_unknown_names
    result = inspector(fixture_path("blog_app")).call(table: %w[nope nada])
    assert_match(/Tables "nope", "nada" not found/, result[:error])
    assert_includes result[:available_tables], "posts"
  end

  def test_table_with_overview_detail
    result = inspector(fixture_path("blog_app")).call(table: ["comments"], detail: "overview")
    assert_equal [{ name: "comments", columns: 6, references: %w[posts users] }], result[:tables]
  end

  def test_search_matches_column_names_case_insensitively
    result = inspector(fixture_path("blog_app")).call(search: "EMAIL")
    assert_equal 1, result[:match_count]
    assert_equal [{ table: "users", columns: [{ name: "email", type: "string", null: false }] }], result[:matches]
  end

  def test_search_matches_table_names
    result = inspector(fixture_path("blog_app")).call(search: "post")
    by_table = result[:matches].to_h { |m| [m[:table], m] }

    assert_equal %w[comments posts posts_tags], by_table.keys
    assert by_table["posts"][:table_name_match]
    assert_includes by_table["posts"][:column_names], "published_at"
    assert_equal ["post_id"], by_table["comments"][:columns].map { |c| c[:name] }
    refute by_table["comments"].key?(:table_name_match)
  end

  def test_search_within_selected_tables
    result = inspector(fixture_path("blog_app")).call(table: %w[comments posts], search: "user_id")
    assert_equal %w[comments posts], result[:matches].map { |m| m[:table] }
  end

  def test_search_without_matches
    result = inspector(fixture_path("blog_app")).call(search: "zzz")
    assert_equal 0, result[:match_count]
    assert_match(/without arguments/, result[:hint])
  end

  def test_search_on_large_schema_stays_small
    with_large_schema do |dir|
      result = inspector(dir).call(search: "contact_email")
      assert_equal 6, result[:match_count]
      assert_operator bytes(result), :<, 2_000
    end
  end

  def test_size_guard_returns_overview_with_a_message
    result = inspector(fixture_path("blog_app"), max_bytes: 500).call(detail: "full")
    assert result[:truncated]
    assert_equal "overview", result[:detail]
    assert_equal 4, result[:tables].size
    assert_match(/over the 0 KB limit|limit/, result[:message])
    assert_match(/table:/, result[:message])
  end

  def test_size_guard_does_not_apply_under_the_limit
    result = inspector(fixture_path("blog_app"), max_bytes: 1_000_000).call(table: "posts")
    refute result.key?(:truncated)
  end

  def test_unknown_detail
    result = inspector(fixture_path("blog_app")).call(detail: "everything")
    assert_match(/Unknown detail/, result[:error])
  end
end
