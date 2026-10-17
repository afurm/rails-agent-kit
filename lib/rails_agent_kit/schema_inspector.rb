# frozen_string_literal: true

module RailsAgentKit
  # Reads the schema of a Rails app at `root` without booting it.
  # Prefers db/schema.rb, falls back to db/structure.sql.
  class SchemaInspector
    def initialize(root)
      @root = File.expand_path(root)
    end

    # Returns a Hash with :source, :tables, ... or :error.
    def call(table: nil)
      schema_rb = File.join(@root, "db", "schema.rb")
      structure_sql = File.join(@root, "db", "structure.sql")

      result =
        if File.file?(schema_rb)
          SchemaParser.parse_file(schema_rb).to_h.merge(source: "db/schema.rb")
        elsif File.file?(structure_sql)
          StructureSqlParser.parse_file(structure_sql).merge(
            source: "db/structure.sql",
            note: "Parsed from db/structure.sql on a best-effort basis; column types are raw SQL and " \
                  "foreign keys/constraints are not extracted. db/schema.rb gives more precise results."
          )
        else
          return { error: "No db/schema.rb or db/structure.sql found under #{@root}. " \
                          "Run `bin/rails db:schema:dump` in the app, or pass --root pointing at the Rails app." }
        end

      filter(result, table)
    end

    private

    def filter(result, table)
      return result if table.nil? || table.to_s.strip.empty?

      tables = result[:tables].select { |t| t[:name] == table.to_s }
      if tables.empty?
        names = result[:tables].map { |t| t[:name] }
        return { error: "Table #{table.inspect} not found in #{result[:source]}.", available_tables: names }
      end

      out = result.merge(tables: tables)
      if out.key?(:foreign_keys)
        out[:foreign_keys] = out[:foreign_keys].select { |fk| fk[:from_table] == table.to_s || fk[:to_table] == table.to_s }
      end
      out
    end
  end
end
