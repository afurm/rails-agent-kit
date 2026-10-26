# frozen_string_literal: true

# Loads a real-world db/schema.rb into a fresh PostgreSQL database and prints the tables and column counts
# that PostgreSQL reports, which is the ground truth the corpus tests compare the parser with.
#
#   ruby script/corpus/load_schema.rb tmp/corpus/external/mastodon.schema.rb
#
# Uses PG* environment variables for the connection. Views (scenic's `create_view`) are created from their
# SQL; triggers (hair_trigger's `create_trigger`) are skipped because they don't change tables or columns.
require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "activerecord", "~> 8.1"
  gem "pg"
end

require "active_record"

path = ARGV.fetch(0)
database = "corpus_#{File.basename(path, '.schema.rb').gsub(/\W/, '_')}"

ActiveRecord::Base.establish_connection(adapter: "postgresql", database: "postgres")
ActiveRecord::Base.connection.drop_database(database)
ActiveRecord::Base.connection.create_database(database)
ActiveRecord::Base.establish_connection(adapter: "postgresql", database: database)

# Database functions and column types that apps define outside schema.rb:
# Mastodon's id defaults call timestamp_id(), Forem's embeddings use pgvector through the neighbor gem.
ActiveRecord::Base.connection.execute(<<~SQL)
  CREATE FUNCTION timestamp_id(text) RETURNS bigint AS 'SELECT 0::bigint' LANGUAGE sql
SQL
ActiveRecord::ConnectionAdapters::PostgreSQL::TableDefinition.class_eval do
  def vector(name, limit: nil, **options) = column(name, limit ? "vector(#{limit})" : "vector", **options)
end

# Accepts any chain of calls and a block, like hair_trigger's builder.
class IgnoredStatement < BasicObject
  def method_missing(*) = self
  def respond_to_missing?(*) = true
end

module CorpusStubs
  def create_view(name, sql_definition:, materialized: false, **)
    kind = materialized ? "MATERIALIZED VIEW" : "VIEW"
    execute("CREATE #{kind} #{connection.quote_table_name(name)} AS #{sql_definition}")
  end

  def create_trigger(*, **) = IgnoredStatement.new
  def create_function(*, **) = nil
end
ActiveRecord::Schema::Definition.prepend(CorpusStubs) if defined?(ActiveRecord::Schema::Definition)
ActiveRecord::Migration.prepend(CorpusStubs)

ActiveRecord::Migration.verbose = false
load File.expand_path(path)
load File.expand_path("count_schema.rb", __dir__)
