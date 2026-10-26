# frozen_string_literal: true

module RailsAgentKit
  # Parses db/schema.rb statically (no eval, no app boot) into tables, columns, indexes, constraints,
  # foreign keys, enums and views.
  #
  # The parser works on statements rather than raw lines: a statement that spans several lines (open
  # brackets, a trailing comma, a method chain or a heredoc) is joined first. It never drops anything
  # silently: a line inside `create_table` or a top-level statement it doesn't understand is reported in
  # `warnings` with its line number, so callers know the result may be incomplete.
  class SchemaParser
    Result = Struct.new(:version, :extensions, :schemas, :enums, :tables, :foreign_keys, :views, :warnings,
                        keyword_init: true) do
      def to_h
        out = { version: version, extensions: extensions }
        out[:schemas] = schemas if schemas.any?
        out[:enums] = enums if enums.any?
        out[:tables] = tables
        out[:foreign_keys] = foreign_keys
        out[:views] = views if views.any?
        out[:warnings] = warnings if warnings.any?
        out
      end
    end

    Statement = Struct.new(:text, :line, :heredoc, keyword_init: true)

    CREATE_TABLE  = /\Acreate_table\s+["']([^"']+)["'](?:\s*,\s*(.*?))?\s+do\s*\|(\w+)\|\z/m
    COLUMN        = /\A(\w+)\.(\w+)\s+["']([^"']+)["']\s*(?:,\s*(.*))?\z/m
    T_INDEX       = /\A(\w+)\.index\s+(.*)\z/m
    T_CONSTRAINT  = /\A(\w+)\.(check|exclusion|unique)_constraint\s+(.*)\z/m
    ADD_INDEX     = /\Aadd_index\s+["']([^"']+)["']\s*,\s*(.*)\z/m
    ADD_FK        = /\Aadd_foreign_key\s+["']([^"']+)["']\s*,\s*["']([^"']+)["']\s*(?:,\s*(.*))?\z/m
    ADD_CHECK     = /\Aadd_check_constraint\s+["']([^"']+)["']\s*,\s*(.*)\z/m
    EXTENSION     = /\Aenable_extension\s+["']([^"']+)["']/
    CREATE_SCHEMA = /\Acreate_schema\s+["']([^"']+)["']/
    CREATE_ENUM   = /\Acreate_enum\s+["']([^"']+)["']\s*,\s*(\[.*\])/m
    CREATE_VIEW   = /\Acreate_view\s+["']([^"']+)["'](?:\s*,\s*(.*))?\z/m
    VIRTUAL_TABLE = /\Acreate_virtual_table\s+["']([^"']+)["']\s*,\s*["']([^"']+)["']\s*,\s*(\[.*\])/m
    VERSION_RE    = /define\(\s*version:\s*([\d_]+)\s*\)/
    DEFINE        = /\AActiveRecord::Schema(?:\[[\d.]+\])?\.define\b/
    HEREDOC       = /<<([~-]?)(["'`]?)([A-Za-z_]\w*)\2/

    def self.parse_file(path)
      new(File.read(path)).parse
    end

    def initialize(source)
      @source = source
    end

    def parse
      @tables = []
      @foreign_keys = []
      @extensions = []
      @schemas = []
      @enums = {}
      @views = []
      @warnings = []
      @table = nil
      @block_var = nil
      @depth = 0 # open `do` blocks outside create_table (other than the define block)

      statements.each { |st| @table ? table_statement(st) : top_level_statement(st) }
      finish_table(@table) if @table

      enums = @enums.map { |name, values| { name: name, values: values } }
      Result.new(version: @source[VERSION_RE, 1]&.delete("_"), extensions: @extensions, schemas: @schemas,
                 enums: enums, tables: @tables, foreign_keys: @foreign_keys, views: @views, warnings: @warnings)
    end

    private

    # --- statements -----------------------------------------------------------------------------------

    def table_statement(st)
      text = st.text
      if text == "end"
        finish_table(@table)
        @table = nil
      elsif (m = T_INDEX.match(text)) && m[1] == @block_var
        @table[:indexes] << build_index(@table[:name], m[2])
      elsif (m = T_CONSTRAINT.match(text)) && m[1] == @block_var
        add_constraint(@table, m[2], m[3])
      elsif (m = COLUMN.match(text)) && m[1] == @block_var
        @table[:columns] << build_column(m[2], m[3], m[4])
      else
        warn(st, "not understood inside create_table #{@table[:name].inspect}, so it is missing from the result")
      end
    end

    def top_level_statement(st)
      text = st.text
      case text
      when CREATE_TABLE then start_table(Regexp.last_match)
      when ADD_INDEX then add_index(Regexp.last_match, st)
      when ADD_FK then add_foreign_key(Regexp.last_match)
      when ADD_CHECK then add_check_constraint(Regexp.last_match, st)
      when EXTENSION then @extensions << Regexp.last_match(1)
      when CREATE_SCHEMA then @schemas << Regexp.last_match(1)
      when CREATE_ENUM then @enums[table_name(Regexp.last_match(1))] = Array(parse_value(Regexp.last_match(2))).map(&:to_s)
      when CREATE_VIEW then add_view(Regexp.last_match)
      when VIRTUAL_TABLE then add_virtual_table(Regexp.last_match)
      when DEFINE then nil
      when "end" then @depth -= 1 if @depth.positive?
      else
        # A statement with its own block (e.g. hair_trigger's create_trigger ... do) ends with its own `end`.
        @depth += 1 if text.match?(/\bdo(\s*\|[^|]*\|)?\z/)
        warn(st, "skipped: only tables, indexes, constraints, foreign keys, enums and views are read")
      end
    end

    def start_table(match)
      opts = parse_options(match[2])
      @block_var = match[3]
      @table = { name: table_name(match[1]), primary_key: primary_key_for(opts), columns: [], indexes: [] }
      @table[:comment] = opts[:comment] if opts[:comment]
      return unless @table[:primary_key].is_a?(String)

      @table[:columns] << { name: @table[:primary_key], type: id_type(opts), null: false, primary_key: true }
    end

    def finish_table(table)
      if table[:primary_key].is_a?(Array)
        table[:columns].each { |c| c[:primary_key] = true if table[:primary_key].include?(c[:name]) }
      end
      table[:columns].each do |c|
        c[:values] = @enums[c[:enum_type]] if c[:enum_type] && @enums.key?(c[:enum_type]) && !c.key?(:values)
      end
      @tables << table
    end

    # Indexes can also belong to a materialized view (scenic's `create_view ..., materialized: true`).
    def add_index(match, st)
      name = table_name(match[1])
      index = build_index(name, match[2])
      target = find_table(name) || @views.find { |v| v[:name] == name }
      return warn(st, "index on unknown table #{match[1].inspect}") unless target

      (target[:indexes] ||= []) << index
    end

    def add_foreign_key(match)
      opts = parse_options(match[3])
      fk = { from_table: table_name(match[1]), to_table: table_name(match[2]) }
      fk[:column] = opts[:column] || "#{singularize(match[2].split('.').last)}_id"
      %i[primary_key on_delete on_update name].each { |k| fk[k] = opts[k] if opts[k] }
      fk[:deferrable] = opts[:deferrable] if opts.key?(:deferrable)
      @foreign_keys << fk
    end

    def add_check_constraint(match, st)
      table = find_table(table_name(match[1]))
      return warn(st, "check constraint on unknown table #{match[1].inspect}") unless table

      add_constraint(table, "check", match[2])
    end

    def add_constraint(table, kind, src)
      args = split_top_level(src)
      constraint = { expression: parse_value(args.shift.to_s) }
      constraint.merge!(parse_options(args.join(", ")).slice(:name, :using, :where, :deferrable, :nulls_not_distinct))
      constraint[:columns] = Array(constraint.delete(:expression)) if kind == "unique" && src.start_with?("[")
      (table[:"#{kind}_constraints"] ||= []) << constraint
    end

    def add_view(match)
      opts = parse_options(match[2])
      view = { name: table_name(match[1]) }
      view[:materialized] = true if opts[:materialized] == true
      @views << view
    end

    # SQLite full-text search tables (Rails 8 `create_virtual_table "posts_search", "fts5", ["title"]`).
    def add_virtual_table(match)
      columns = Array(parse_value(match[3])).map { |name| { name: name.to_s, type: "text", null: true } }
      @tables << { name: match[1], primary_key: nil, virtual: match[2], columns: columns, indexes: [] }
    end

    # With several schemas on the search path Rails dumps every table and enum qualified ("public.users").
    # Names in the default `public` schema are reported plain; other schemas keep the prefix.
    def table_name(name)
      name.delete_prefix("public.")
    end

    def find_table(name)
      @tables.find { |t| t[:name] == name } || (@table if @table && @table[:name] == name)
    end

    def warn(st, message)
      @warnings << { line: st.line, statement: abbreviate(st.text), message: message }
    end

    def abbreviate(text)
      one_line = text.gsub(/\s+/, " ")
      one_line.length > 120 ? "#{one_line[0, 117]}..." : one_line
    end

    # --- building ---------------------------------------------------------------------------------------

    def build_column(type, name, opts_src)
      opts = parse_options(opts_src)
      if type == "virtual"
        col = { name: name, type: opts[:type]&.to_s || "virtual", null: opts.key?(:null) ? opts[:null] : true }
        col[:virtual] = true
        col[:as] = opts[:as] if opts.key?(:as)
        col[:stored] = opts[:stored] if opts.key?(:stored)
      else
        col = { name: name, type: type, null: opts.key?(:null) ? opts[:null] : true }
      end
      %i[default limit precision scale array comment enum_type collation].each { |k| col[k] = opts[k] if opts.key?(k) }
      col[:enum_type] = table_name(col[:enum_type].to_s) if col[:enum_type]
      col
    end

    # `src` is the column list (an array, one name, or an SQL expression string) followed by options.
    def build_index(table, src)
      args = split_top_level(src)
      columns = parse_value(args.shift.to_s)
      opts = parse_options(args.join(", "))
      index = { table: table, name: opts[:name], columns: Array(columns), unique: opts[:unique] == true }
      %i[where using order opclass include nulls_not_distinct].each { |k| index[k] = opts[k] if opts.key?(k) }
      index
    end

    def primary_key_for(opts)
      return nil if opts[:id] == false
      return opts[:primary_key].map(&:to_s) if opts[:primary_key].is_a?(Array)

      opts[:primary_key] || "id"
    end

    def id_type(opts)
      case (id = opts[:id])
      when nil, true then "bigint"
      when /\A\{(.*)\}\z/m then parse_options(Regexp.last_match(1))[:type]&.to_s || "bigint"
      else id.to_s
      end
    end

    def singularize(word)
      if word.end_with?("ies") then word[0..-4] + "y"
      elsif word.end_with?("ses") then word[0..-3]
      elsif word.end_with?("s") then word[0..-2]
      else word
      end
    end

    # --- lexing -----------------------------------------------------------------------------------------

    # Splits the source into statements: comments removed, continuation lines joined, heredoc bodies attached
    # to the statement that opened them.
    def statements
      lines = @source.lines
      out = []
      i = 0
      while i < lines.size
        start = i
        text = strip_comment(lines[i]).strip
        i += 1
        next if text.empty?

        heredoc = +""
        loop do
          # Heredoc bodies follow the line that opens them; skip to their terminators.
          text.scan(HEREDOC).each do |_, _, id|
            while i < lines.size
              body_line = lines[i]
              i += 1
              break if body_line.strip == id

              heredoc << body_line
            end
          end
          break unless continues?(text) && i < lines.size

          nxt = strip_comment(lines[i]).strip
          i += 1
          text = "#{text} #{nxt}".strip
        end
        if text.match?(/\A#{HEREDOC}\z/) && out.any?
          # A heredoc on its own line is the body of the block the previous statement opened.
          out.last.heredoc = "#{out.last.heredoc}#{heredoc}"
          next
        end
        out << Statement.new(text: text, line: start + 1, heredoc: heredoc.empty? ? nil : heredoc)
      end
      out
    end

    # True while brackets are open, or the line ends with `,`, `.` or `\`, or opens a lambda/hash.
    def continues?(text)
      depth = 0
      in_str = nil
      text.each_char.with_index do |ch, idx|
        if in_str
          in_str = nil if ch == in_str && !escaped?(text, idx)
          next
        end
        case ch
        when '"', "'" then in_str = ch
        when "[", "{", "(" then depth += 1
        when "]", "}", ")" then depth -= 1
        end
      end
      return true if in_str || depth.positive?

      text.end_with?(",", ".", "\\", "||", "&&")
    end

    def escaped?(text, idx)
      backslashes = 0
      j = idx - 1
      while j >= 0 && text[j] == "\\"
        backslashes += 1
        j -= 1
      end
      backslashes.odd?
    end

    # Removes a trailing `# comment` that is not inside a string literal.
    def strip_comment(line)
      in_str = nil
      line.each_char.with_index do |ch, i|
        if in_str
          in_str = nil if ch == in_str && !escaped?(line, i)
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
        elsif (m = part.match(/\A\s*:?["']?(\w+)["']?\s*=>\s*(.*)\z/m))
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
      when /\A"(.*)"\z/m then unescape(Regexp.last_match(1))
      when /\A'(.*)'\z/m then Regexp.last_match(1)
      when /\A:(\w+)\z/ then Regexp.last_match(1)
      when /\A\[(.*)\]\z/m then split_top_level(Regexp.last_match(1)).map { |v| parse_value(v) }
      else s # lambdas (-> { "now()" }), constants, etc. are kept verbatim
      end
    end

    def unescape(str)
      str.gsub(/\\(.)/) do
        case Regexp.last_match(1)
        when "n" then "\n"
        when "t" then "\t"
        else Regexp.last_match(1)
        end
      end
    end

    def split_top_level(src)
      parts = []
      depth = 0
      in_str = nil
      buf = +""
      src.each_char.with_index do |ch, i|
        if in_str
          in_str = nil if ch == in_str && !escaped?(src, i)
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
