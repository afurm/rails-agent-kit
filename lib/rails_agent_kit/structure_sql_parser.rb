# frozen_string_literal: true

module RailsAgentKit
  # Best-effort parser for db/structure.sql (CREATE TABLE / CREATE INDEX / simple PostgreSQL foreign keys).
  # SQL dumps vary a lot between adapters, so results are approximate.
  class StructureSqlParser
    CREATE_TABLE = /CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?((?:[\w"`]+\.)?[\w"`]+)\s*\((.*?)\)\s*;/mi
    CREATE_INDEX = /CREATE\s+(UNIQUE\s+)?INDEX\s+(?:IF\s+NOT\s+EXISTS\s+)?([\w"`]+)\s+ON\s+((?:[\w"`]+\.)?[\w"`]+)(?:\s+USING\s+\w+)?\s*\((.*?)\)\s*(?:WHERE\s+(.*?))?;/mi
    PG_IDENTIFIER = /(?:[a-z_][a-z0-9_$]*|"[A-Za-z_][A-Za-z0-9_$]*")/i
    PG_TABLE = /(?:#{PG_IDENTIFIER}\s*\.\s*)?#{PG_IDENTIFIER}/
    ADD_FOREIGN_KEY = /\A\s*ALTER\s+TABLE\s+(?:ONLY\s+)?(#{PG_TABLE})\s+ADD\s+CONSTRAINT\s+(#{PG_IDENTIFIER})\s+FOREIGN\s+KEY\s*\(\s*(#{PG_IDENTIFIER})\s*\)\s+REFERENCES\s+(#{PG_TABLE})\s*\(\s*(#{PG_IDENTIFIER})\s*\)\s*\z/i
    CONSTRAINT_WORDS = /\A(CONSTRAINT|PRIMARY|FOREIGN|UNIQUE|CHECK|KEY|INDEX|EXCLUDE)\b/i

    def self.parse_file(path)
      new(File.read(path)).parse
    end

    def initialize(source)
      @raw_source = source
      @source = source.gsub(/--[^\n]*/, "")
    end

    def parse
      tables = @source.scan(CREATE_TABLE).map do |name, body|
        columns = split_columns(body).filter_map do |defn|
          next if defn.match?(CONSTRAINT_WORDS)

          m = defn.match(/\A([\w"`]+)\s+(.+)\z/m) or next
          rest = m[2]
          type = rest.sub(/\s+(NOT\s+NULL|NULL|DEFAULT|PRIMARY|REFERENCES|UNIQUE|CHECK|COLLATE|GENERATED|CONSTRAINT|AUTO_INCREMENT)\b.*\z/mi, "").strip
          {
            name: unquote(m[1]),
            type: type,
            null: !rest.match?(/NOT\s+NULL/i) && !rest.match?(/PRIMARY\s+KEY/i),
            primary_key: rest.match?(/PRIMARY\s+KEY/i) || nil
          }.compact
        end
        { name: unquote(name.split(".").last), columns: columns, indexes: [] }
      end

      @source.scan(CREATE_INDEX).each do |unique, idx_name, table, cols, where|
        t = tables.find { |tt| tt[:name] == unquote(table.split(".").last) }
        next unless t

        idx = { table: t[:name], name: unquote(idx_name), columns: cols.split(",").map { |c| unquote(c.strip.split(/\s+/).first) }, unique: !unique.nil? }
        idx[:where] = where.strip if where
        t[:indexes] << idx
      end

      result = { tables: tables }
      foreign_keys = parse_foreign_keys(tables)
      result[:foreign_keys] = foreign_keys unless foreign_keys.empty?
      result
    end

    private

    # Tokenize only to find statement boundaries. Quoted text and function bodies
    # must never become SQL statements; comments may appear between SQL tokens.
    def sql_statements
      tokens = @raw_source.scan(/--[^\n]*|\/\*|\*\/|\$[A-Za-z_0-9]*\$|'(?:[^'\\]|\\.|'')*'|"(?:[^"]|"")*"|;|[^'";\/\*$-]+|./m)
      statements = []
      statement = +""
      comment_depth = 0
      dollar_quote = nil
      tokens.each do |token|
        if comment_depth.positive?
          comment_depth += 1 if token == "/*"
          comment_depth -= 1 if token == "*/"
        elsif dollar_quote
          dollar_quote = nil if token == dollar_quote
        elsif token == "/*"
          comment_depth = 1
          statement << " "
        elsif token.start_with?("--")
          statement << " "
        elsif token.match?(/\A\$(?:[A-Za-z_][A-Za-z_0-9]*)?\$\z/)
          dollar_quote = token
          statement << "?"
        elsif token == "'" || token == '"'
          break # An unterminated quote cannot contain a trustworthy statement.
        elsif token.start_with?("'")
          statement << "?"
        elsif token == ";"
          statements << statement
          statement = +""
        else
          statement << token
        end
      end
      statements
    end

    def pg_identifier(name)
      name.start_with?('"') ? name[1...-1] : name.downcase
    end

    def pg_table(name)
      parts = name.split(/\s*\.\s*/).map { |part| pg_identifier(part) }
      return unless parts.size == 1 || parts.first == "public"

      parts.last
    end

    def parse_foreign_keys(tables)
      # The existing table parser drops schema qualifiers. Avoid attaching a key
      # to an ambiguous table or one from a non-public schema.
      statements = sql_statements
      eligible = statements.flat_map { |statement| "#{statement};".scan(CREATE_TABLE) }
                           .group_by { |name, _| unquote(name.split(".").last) }
      statements.filter_map do |statement|
        match = ADD_FOREIGN_KEY.match(statement) or next
        from = pg_table(match[1])
        to = pg_table(match[4])
        next unless [from, to].all? do |name|
          definitions = eligible[name]
          name && definitions && definitions.size == 1 && pg_table(definitions.first.first) == name &&
            tables.count { |table| table[:name] == name } == 1
        end
        source = tables.find { |table| table[:name] == from }
        target = tables.find { |table| table[:name] == to }
        column = pg_identifier(match[3])
        primary_key = pg_identifier(match[5])
        next unless source[:columns].any? { |c| c[:name] == column } &&
                    target[:columns].any? { |c| c[:name] == primary_key }

        { from_table: from, to_table: to, column: column,
          primary_key: primary_key, name: pg_identifier(match[2]) }
      end
    end

    def unquote(s)
      s.to_s.delete('"`')
    end

    def split_columns(body)
      parts = []
      depth = 0
      buf = +""
      body.each_char do |ch|
        depth += 1 if ch == "("
        depth -= 1 if ch == ")"
        if ch == "," && depth.zero?
          parts << buf.strip
          buf = +""
        else
          buf << ch
        end
      end
      parts << buf.strip unless buf.strip.empty?
      parts
    end
  end
end
