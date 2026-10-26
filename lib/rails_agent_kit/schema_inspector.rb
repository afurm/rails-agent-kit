# frozen_string_literal: true

require "json"

module RailsAgentKit
  # Reads the schema of a Rails app at `root` without booting it.
  # Prefers db/schema.rb, falls back to db/structure.sql.
  #
  # Agents usually call the schema tool with no arguments first, and a real app can have hundreds of tables,
  # so the default answer is a compact overview (table names, column counts, primary keys and foreign key
  # targets). Details come from `table:` (one name, an array, or a comma-separated list), `search:` (a
  # case-insensitive match on table or column names) or `detail: "full"`.
  class SchemaInspector
    DETAILS = %w[overview full].freeze

    # Responses larger than this (serialized JSON, in bytes) are replaced by the overview plus a note on
    # how to narrow the request, so a single call can't flood the agent's context.
    MAX_BYTES = 60_000

    OVERVIEW_HINT = "This is an overview. Pass table: \"users\" (or an array of names) for columns, indexes and " \
                    "foreign keys, search: \"email\" to find tables and columns by name, or detail: \"full\" " \
                    "for the whole schema."

    def initialize(root, max_bytes: MAX_BYTES)
      @root = File.expand_path(root)
      @max_bytes = max_bytes
    end

    # Returns a Hash with :source, :tables, ... or :error.
    #
    # - table:  a table name, an Array of names, or "a, b". Returns those tables in full.
    # - search: case-insensitive substring of a table or column name.
    # - detail: "overview" or "full". Defaults to "full" when `table` or `search` is given, else "overview".
    def call(table: nil, search: nil, detail: nil)
      result = load_schema
      return result if result.key?(:error)

      names = normalize_tables(table)
      search = search.to_s.strip
      detail = detail.to_s.strip.downcase
      detail = nil if detail.empty?
      if detail && !DETAILS.include?(detail)
        return { error: "Unknown detail #{detail.inspect}. Use \"overview\" or \"full\"." }
      end

      if names.any?
        result = select_tables(result, names)
        return result if result.key?(:error)
      end

      return search_result(result, search) unless search.empty?

      detail ||= names.any? ? "full" : "overview"
      out = detail == "overview" ? overview(result) : result
      guard_size(out, result)
    end

    private

    def load_schema
      schema_rb = File.join(@root, "db", "schema.rb")
      structure_sql = File.join(@root, "db", "structure.sql")

      if File.file?(schema_rb)
        SchemaParser.parse_file(schema_rb).to_h.merge(source: "db/schema.rb")
      elsif File.file?(structure_sql)
        StructureSqlParser.parse_file(structure_sql).merge(
          source: "db/structure.sql",
          note: "Parsed from db/structure.sql on a best-effort basis; column types are raw SQL and " \
                "foreign keys/constraints are not extracted. db/schema.rb gives more precise results."
        )
      else
        { error: "No db/schema.rb or db/structure.sql found under #{@root}. " \
                 "Run `bin/rails db:schema:dump` in the app, or pass --root pointing at the Rails app." }
      end
    end

    def normalize_tables(table)
      Array(table).flat_map { |t| t.to_s.split(",") }.map(&:strip).reject(&:empty?).uniq
    end

    def select_tables(result, names)
      known = result[:tables].map { |t| t[:name] }
      missing = names - known
      if missing.size == names.size
        label = names.size == 1 ? "Table #{names.first.inspect}" : "Tables #{names.map(&:inspect).join(', ')}"
        return { error: "#{label} not found in #{result[:source]}.", available_tables: known }
      end

      out = result.merge(tables: result[:tables].select { |t| names.include?(t[:name]) })
      if out.key?(:foreign_keys)
        out[:foreign_keys] = out[:foreign_keys].select do |fk|
          names.include?(fk[:from_table]) || names.include?(fk[:to_table])
        end
      end
      out[:missing_tables] = missing if missing.any?
      out
    end

    def overview(result)
      fks = Array(result[:foreign_keys]).group_by { |fk| fk[:from_table] }
      tables = result[:tables].map do |t|
        entry = { name: t[:name], columns: t[:columns].size }
        entry[:primary_key] = t[:primary_key] || false if t.key?(:primary_key) && t[:primary_key] != "id"
        refs = Array(fks[t[:name]]).map { |fk| fk[:to_table] }.uniq
        entry[:references] = refs if refs.any?
        entry
      end
      out = meta(result).merge(detail: "overview", table_count: tables.size, hint: OVERVIEW_HINT, tables: tables)
      out[:enums] = result[:enums] if result[:enums]
      out[:views] = result[:views].map { |v| v[:name] } if result[:views]
      out
    end

    def search_result(result, search)
      needle = search.downcase
      matches = result[:tables].filter_map do |t|
        table_match = t[:name].downcase.include?(needle)
        columns = t[:columns].select { |c| c[:name].downcase.include?(needle) }
        next unless table_match || columns.any?

        entry = { table: t[:name] }
        entry[:table_name_match] = true if table_match
        entry[:columns] = columns.map { |c| c.slice(:name, :type, :null, :primary_key).compact }
        entry[:column_names] = t[:columns].map { |c| c[:name] } if table_match
        entry
      end
      out = meta(result).merge(search: search, match_count: matches.size, matches: matches)
      if matches.empty?
        out[:hint] = "No table or column name contains #{search.inspect}. Call rails_schema without arguments " \
                     "for the list of tables."
      end
      out[:missing_tables] = result[:missing_tables] if result[:missing_tables]
      guard_size(out, result)
    end

    # Parser warnings travel with every answer: they mark statements that are missing from the result.
    def meta(result)
      result.slice(:source, :version, :note, :warnings)
    end

    def guard_size(out, result)
      size = JSON.generate(out).bytesize
      return out if size <= @max_bytes || out[:detail] == "overview"

      overview(result).merge(
        truncated: true,
        message: "The full answer is #{size / 1024} KB, over the #{@max_bytes / 1024} KB limit, so this is the " \
                 "overview instead. Narrow the request: pass table: with one or a few table names, or search: " \
                 "with part of a table or column name."
      )
    end
  end
end
