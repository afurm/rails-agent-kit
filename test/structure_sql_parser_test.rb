# frozen_string_literal: true

require_relative "test_helper"

class StructureSqlParserTest < Minitest::Test
  include FixtureHelpers

  def setup
    @sql = File.read(fixture_path("pg_foreign_keys", "db", "structure.sql"))
    @tables = @sql.split("ALTER TABLE ONLY").first
  end

  def parse(sql)
    RailsAgentKit::StructureSqlParser.new(sql).parse
  end

  def fk(clause = "FOREIGN KEY (account_id) REFERENCES public.accounts(id)")
    "ALTER TABLE ONLY public.entries ADD CONSTRAINT fk_test #{clause};"
  end

  def test_named_single_column_foreign_keys
    result = parse(@sql)
    assert_equal [
      { from_table: "entries", to_table: "accounts", column: "account_id", primary_key: "id", name: "fk_entries_account" },
      { from_table: "entries", to_table: "accounts", column: "account_code", primary_key: "code", name: "fk_entries_code" },
      { from_table: "entries", to_table: "entries", column: "parent_id", primary_key: "id", name: "fk_entries_parent" }
    ], result[:foreign_keys]
    assert_equal parse(@tables)[:tables], result[:tables]
    assert_equal "fk_test$", parse(@tables + fk.sub("fk_test", "fk_test$"))[:foreign_keys][0][:name]
  end

  def test_unsupported_statements_do_not_change_existing_output
    unsupported = [
      fk("FOREIGN KEY (account_id, account_code) REFERENCES accounts(id, code)"),
      fk("FOREIGN KEY (account_id) REFERENCES accounts(id, code)"),
      fk("FOREIGN KEY (account_id) REFERENCES accounts"),
      fk("FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE"),
      fk("FOREIGN KEY (account_id) REFERENCES accounts(id) ON UPDATE NO ACTION"),
      fk("FOREIGN KEY (account_id) REFERENCES accounts(id) DEFERRABLE INITIALLY DEFERRED"),
      fk("FOREIGN KEY (account_id) REFERENCES accounts(id) NOT VALID"),
      fk("FOREIGN KEY (account_id) REFERENCES accounts(id) MATCH FULL"),
      fk("FOREIGN KEY (account_id) REFERENCES other.accounts(id)"),
      fk("FOREIGN KEY (missing) REFERENCES accounts(id)"),
      fk("FOREIGN KEY (account_id) REFERENCES accounts(missing)"),
      fk("FOREIGN KEY (account_id) REFERENCES missing(id)"),
      fk.sub("public.entries", "other.entries"),
      fk.sub("public.entries", "missing"),
      fk.sub("ADD CONSTRAINT fk_test", "ADD"),
      fk.sub("public.entries", "`entries`"),
      fk.sub("fk_test", '"fk with spaces"'),
      fk.sub(";", ", ADD CONSTRAINT another UNIQUE (id);"),
      fk.delete_suffix(";")
    ]
    baseline = parse(@tables)
    unsupported.each { |sql| assert_equal baseline, parse(@tables + sql), sql }
  end

  def test_comments_and_literals_cannot_invent_foreign_keys
    ["-- #{fk}\n", "/* #{fk} */", "/* outer /* nested */ #{fk} */",
     "COMMENT ON TABLE entries IS '#{fk}';",
     "DO $$ BEGIN #{fk} END $$;", "DO $body$ BEGIN #{fk} END $body$;"].each do |sql|
      assert_equal parse(@tables), parse(@tables + sql), sql
    end
    assert_equal "fk_test", parse(@tables + fk.sub("ADD CONSTRAINT", "ADD /* comment */ CONSTRAINT"))[:foreign_keys][0][:name]
  end

  def test_quoted_case_and_comments_between_tokens
    sql = <<~SQL
      CREATE TABLE public."Accounts" ("Id" bigint);
      CREATE TABLE public."Entries" ("AccountId" bigint);
      ALTER TABLE ONLY public."Entries" ADD CONSTRAINT "FK_Account"
        FOREIGN KEY ("AccountId") -- source column
        REFERENCES public."Accounts"("Id");
    SQL
    assert_equal [{ from_table: "Entries", to_table: "Accounts", column: "AccountId",
                    primary_key: "Id", name: "FK_Account" }], parse(sql)[:foreign_keys]
  end

  def test_unterminated_quotes_and_comments_are_not_statements
    ["'", '"', "/*", "$$", "$body$"].each do |opening|
      assert_equal parse(@tables), parse(@tables + opening + ";" + fk), opening
    end
  end

  def test_ambiguous_or_non_public_tables_are_not_attached
    ["CREATE TABLE other.accounts (id bigint);", "CREATE TABLE accounts (id bigint);"].each do |sql|
      refute parse(@tables + sql + fk).key?(:foreign_keys)
    end
    sql = @tables.sub("public.accounts", "other.accounts") + fk
    refute parse(sql).key?(:foreign_keys)
  end

  def test_table_definitions_in_comments_cannot_supply_foreign_key_metadata
    sql = "/* #{@tables} */" + fk
    refute parse(sql).key?(:foreign_keys)
  end

  def test_existing_sql_fixture_retains_its_result_shape
    result = RailsAgentKit::StructureSqlParser.parse_file(fixture_path("sql_app", "db", "structure.sql"))
    assert_equal [:tables], result.keys
    assert_equal %w[accounts ledger_entries], result[:tables].map { |t| t[:name] }
    assert_equal [1, 1], result[:tables].map { |t| t[:indexes].size }
  end

  def test_inspector_full_filter_overview_and_size_guard
    inspector = RailsAgentKit::SchemaInspector.new(fixture_path("pg_foreign_keys"))
    full = inspector.call(detail: "full")
    assert_equal parse(@sql)[:foreign_keys], full[:foreign_keys]
    assert_equal 2, inspector.call(table: "accounts")[:foreign_keys].size
    assert_equal 3, inspector.call(table: "entries")[:foreign_keys].size
    assert_empty inspector.call(table: "unrelated")[:foreign_keys]
    overview = inspector.call
    assert_equal %w[accounts entries], overview[:tables].find { |t| t[:name] == "entries" }[:references]
    refute overview[:tables].find { |t| t[:name] == "accounts" }.key?(:references)
    assert_equal "db/structure.sql", full[:source]
    assert_match(/only named single-column PostgreSQL foreign keys/, full[:note])
    truncated = RailsAgentKit::SchemaInspector.new(fixture_path("pg_foreign_keys"), max_bytes: 1).call(detail: "full")
    assert truncated[:truncated]
    assert_equal overview[:tables], truncated[:tables]
  end
end
