# frozen_string_literal: true

# Prints the tables and per-table column counts of the connected database as JSON. Run it inside a booted app
# (`bin/rails runner script/corpus/count_schema.rb`) or after `load_schema.rb` has loaded a schema.rb.
#
# PostgreSQL tables outside the `public` schema are named `schema.table`, the way db/schema.rb dumps them.
require "json"

connection = ActiveRecord::Base.connection
internal = [ActiveRecord::Base.schema_migrations_table_name, ActiveRecord::Base.internal_metadata_table_name]
views = connection.views.sort

tables =
  if connection.adapter_name.match?(/postg/i)
    connection.select_rows(<<~SQL).map { |schema, name| schema == "public" ? name : "#{schema}.#{name}" }
      SELECT table_schema, table_name FROM information_schema.tables
      WHERE table_type = 'BASE TABLE' AND table_schema = ANY (current_schemas(false))
    SQL
  else
    connection.tables
  end
tables = (tables - internal - views).sort

out = { tables: tables.to_h { |t| [t, connection.columns(t).size] } }
out[:views] = views if views.any?
puts JSON.pretty_generate(out)
