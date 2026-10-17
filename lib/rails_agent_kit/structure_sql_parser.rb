# frozen_string_literal: true

module RailsAgentKit
  # Best-effort parser for db/structure.sql (CREATE TABLE / CREATE INDEX).
  # SQL dumps vary a lot between adapters, so results are approximate.
  class StructureSqlParser
    CREATE_TABLE = /CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?((?:[\w"`]+\.)?[\w"`]+)\s*\((.*?)\)\s*;/mi
    CREATE_INDEX = /CREATE\s+(UNIQUE\s+)?INDEX\s+(?:IF\s+NOT\s+EXISTS\s+)?([\w"`]+)\s+ON\s+((?:[\w"`]+\.)?[\w"`]+)(?:\s+USING\s+\w+)?\s*\((.*?)\)\s*(?:WHERE\s+(.*?))?;/mi
    CONSTRAINT_WORDS = /\A(CONSTRAINT|PRIMARY|FOREIGN|UNIQUE|CHECK|KEY|INDEX|EXCLUDE)\b/i

    def self.parse_file(path)
      new(File.read(path)).parse
    end

    def initialize(source)
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

      { tables: tables }
    end

    private

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
