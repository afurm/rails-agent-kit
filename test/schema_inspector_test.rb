# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"

class SchemaInspectorTest < Minitest::Test
  include FixtureHelpers

  def test_prefers_schema_rb
    result = RailsAgentKit::SchemaInspector.new(fixture_path("blog_app")).call(detail: "full")
    assert_equal "db/schema.rb", result[:source]
    assert_equal 4, result[:tables].size
  end

  def test_filters_by_table_including_related_foreign_keys
    result = RailsAgentKit::SchemaInspector.new(fixture_path("blog_app")).call(table: "posts")
    assert_equal ["posts"], result[:tables].map { |t| t[:name] }
    assert_equal 2, result[:foreign_keys].size
  end

  def test_unknown_table
    result = RailsAgentKit::SchemaInspector.new(fixture_path("blog_app")).call(table: "nope")
    assert_match(/not found/, result[:error])
    assert_includes result[:available_tables], "users"
  end

  def test_falls_back_to_structure_sql
    result = RailsAgentKit::SchemaInspector.new(fixture_path("sql_app")).call(detail: "full")
    assert_equal "db/structure.sql", result[:source]
    assert_match(/best-effort/, result[:note])

    accounts = result[:tables].find { |t| t[:name] == "accounts" }
    assert_equal %w[id name balance created_at], accounts[:columns].map { |c| c[:name] }
    assert_equal "numeric(10,2)", accounts[:columns][2][:type]
    assert_equal false, accounts[:columns][1][:null]
    assert_equal [{ table: "accounts", name: "index_accounts_on_name", columns: ["name"], unique: true }], accounts[:indexes]

    ledger = result[:tables].find { |t| t[:name] == "ledger_entries" }
    assert_equal true, ledger[:columns][0][:primary_key]
    assert_equal "integer", ledger[:columns][0][:type]
    assert_equal ["account_id"], ledger[:indexes][0][:columns]
  end

  def test_missing_schema
    Dir.mktmpdir do |dir|
      result = RailsAgentKit::SchemaInspector.new(dir).call
      assert_match(/No db\/schema.rb or db\/structure.sql/, result[:error])
    end
  end
end
