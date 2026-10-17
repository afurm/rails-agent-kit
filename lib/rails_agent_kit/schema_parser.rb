# frozen_string_literal: true

module RailsAgentKit
  # Parses db/schema.rb statically (no eval, no app boot) into tables, columns,
  # indexes and foreign keys.
  class SchemaParser
    Result = Struct.new(:version, :extensions, :tables, :foreign_keys, keyword_init: true) do
      def to_h
        { version: version, extensions: extensions, tables: tables, foreign_keys: foreign_keys }
      end
    end

    CREATE_TABLE = /\A\s*create_table\s+["']([^"']+)["'](?:\s*,\s*(.*?))?\s+do\s*\|(\w+)\|\s*\z/
    COLUMN       = /\A\s*(\w+)\.(\w+)\s+["']([^"']+)["']\s*(?:,\s*(.*))?\z/
    T_INDEX      = /\A\s*(\w+)\.index\s+(\[[^\]]*\]|["'][^"']*["'])\s*(?:,\s*(.*))?\z/
    ADD_INDEX    = /\A\s*add_index\s+["']([^"']+)["']\s*,\s*(\[[^\]]*\]|["'][^"']*["'])\s*(?:,\s*(.*))?\z/
    ADD_FK       = /\A\s*add_foreign_key\s+["']([^"']+)["']\s*,\s*["']([^"']+)["']\s*(?:,\s*(.*))?\z/
    EXTENSION    = /\A\s*enable_extension\s+["']([^"']+)["']/
    VERSION_RE   = /define\(\s*version:\s*([\d_]+)\s*\)/

    def self.parse_file(path)
      new(File.read(path)).parse
    end

    def initialize(source)
      @source = source
    end

    def parse
      tables = []
      foreign_keys = []
      extensions = []
      version = @source[VERSION_RE, 1]&.delete("_")
      current = nil
      block_var = nil

      @source.each_line do |raw|
        line = strip_comment(raw).rstrip
        next if line.strip.empty?

        if current
          if line.strip == "end"
            tables << current
            current = nil
          elsif (m = T_INDEX.match(line)) && m[1] == block_var
            current[:indexes] << build_index(current[:name], m[2], m[3])
          elsif (m = COLUMN.match(line)) && m[1] == block_var
            current[:columns] << build_column(m[2], m[3], m[4])
          end
          next
        end

        if (m = CREATE_TABLE.match(line))
          opts = parse_options(m[2])
          block_var = m[3]
          current = { name: m[1], primary_key: primary_key_for(opts), columns: [], indexes: [] }
          current[:comment] = opts[:comment] if opts[:comment]
          if current[:primary_key]
            current[:columns] << { name: current[:primary_key], type: id_type(opts), null: false, primary_key: true }
          end
        elsif (m = ADD_INDEX.match(line))
          index = build_index(m[1], m[2], m[3])
          table = tables.find { |t| t[:name] == m[1] }
          table ? table[:indexes] << index : nil
        elsif (m = ADD_FK.match(line))
          opts = parse_options(m[3])
          fk = { from_table: m[1], to_table: m[2] }
          fk[:column] = opts[:column] || "#{singularize(m[2])}_id"
          fk[:primary_key] = opts[:primary_key] if opts[:primary_key]
          fk[:on_delete] = opts[:on_delete] if opts[:on_delete]
          fk[:on_update] = opts[:on_update] if opts[:on_update]
          fk[:name] = opts[:name] if opts[:name]
          foreign_keys << fk
        elsif (m = EXTENSION.match(line))
          extensions << m[1]
        end
      end

      Result.new(version: version, extensions: extensions, tables: tables, foreign_keys: foreign_keys)
    end

    private

    def build_column(type, name, opts_src)
      opts = parse_options(opts_src)
      col = { name: name, type: type, null: opts.key?(:null) ? opts[:null] : true }
      %i[default limit precision scale array comment].each { |k| col[k] = opts[k] if opts.key?(k) }
      col
    end

    def build_index(table, cols_src, opts_src)
      opts = parse_options(opts_src)
      columns = parse_value(cols_src)
      index = { table: table, name: opts[:name], columns: Array(columns), unique: opts[:unique] == true }
      %i[where using order].each { |k| index[k] = opts[k] if opts.key?(k) }
      index
    end

    def primary_key_for(opts)
      return nil if opts[:id] == false
      return nil if opts[:primary_key].is_a?(Array)

      opts[:primary_key] || "id"
    end

    def id_type(opts)
      case opts[:id]
      when nil, true then "bigint"
      else opts[:id].to_s
      end
    end

    def singularize(word)
      if word.end_with?("ies") then word[0..-4] + "y"
      elsif word.end_with?("ses") then word[0..-3]
      elsif word.end_with?("s") then word[0..-2]
      else word
      end
    end

    # Removes a trailing `# comment` that is not inside a string literal.
    def strip_comment(line)
      in_str = nil
      line.each_char.with_index do |ch, i|
        if in_str
          in_str = nil if ch == in_str && line[i - 1] != "\\"
        elsif ch == '"' || ch == "'"
          in_str = ch
        elsif ch == "#"
          return line[0...i]
        end
      end
      line
    end

    # Parses `key: value, key2: value2` into a symbol-keyed hash.
    def parse_options(src)
      return {} if src.nil? || src.strip.empty?

      split_top_level(src).each_with_object({}) do |part, h|
        if (m = part.match(/\A\s*(\w+):\s*(.*)\z/m))
          h[m[1].to_sym] = parse_value(m[2].strip)
        elsif (m = part.match(/\A\s*["'](\w+)["']\s*=>\s*(.*)\z/m))
          h[m[1].to_sym] = parse_value(m[2].strip)
        end
      end
    end

    def parse_value(src)
      s = src.strip
      case s
      when "true" then true
      when "false" then false
      when "nil" then nil
      when /\A-?\d+\z/ then s.to_i
      when /\A-?\d+\.\d+\z/ then s.to_f
      when /\A"(.*)"\z/m then Regexp.last_match(1).gsub('\\"', '"')
      when /\A'(.*)'\z/m then Regexp.last_match(1)
      when /\A:(\w+)\z/ then Regexp.last_match(1)
      when /\A\[(.*)\]\z/m then split_top_level(Regexp.last_match(1)).map { |v| parse_value(v) }
      else s # lambdas (-> { "now()" }), constants, etc. are kept verbatim
      end
    end

    def split_top_level(src)
      parts = []
      depth = 0
      in_str = nil
      buf = +""
      src.each_char.with_index do |ch, i|
        if in_str
          in_str = nil if ch == in_str && src[i - 1] != "\\"
          buf << ch
          next
        end
        case ch
        when '"', "'" then in_str = ch
        when "[", "{", "(" then depth += 1
        when "]", "}", ")" then depth -= 1
        when ","
          if depth.zero?
            parts << buf
            buf = +""
            next
          end
        end
        buf << ch
      end
      parts << buf unless buf.strip.empty?
      parts.map(&:strip)
    end
  end
end
