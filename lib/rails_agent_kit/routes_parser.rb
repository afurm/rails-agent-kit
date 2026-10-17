# frozen_string_literal: true

module RailsAgentKit
  # Parses the output of `bin/rails routes --expanded` (preferred) or the
  # default table output of `bin/rails routes`.
  class RoutesParser
    HEADER = /\A--\[\s*Route\s+\d+\s*\]-*\s*\z/
    FIELD  = /\A([^|]+?)\s*\|\s?(.*)\z/
    KEYS = {
      "Prefix" => :name,
      "Verb" => :verb,
      "URI" => :path,
      "Controller#Action" => :action,
      "Source Location" => :source_location
    }.freeze

    def self.parse(output)
      new(output).parse
    end

    def initialize(output)
      @output = output.to_s
    end

    TABLE_HEADER = /\A\s*Prefix\s+Verb\s+URI Pattern\s+Controller#Action/

    def parse
      lines = @output.lines.map(&:chomp)
      header = lines.find { |l| TABLE_HEADER.match?(l) }
      return parse_table(lines, header) if header && lines.none? { |l| HEADER.match?(l.strip) }

      parse_expanded
    end

    private

    def parse_table(lines, header)
      verb_at = header.index("Verb")
      uri_at = header.index("URI Pattern")
      action_at = header.index("Controller#Action")
      lines.drop(lines.index(header) + 1).filter_map do |line|
        next if line.strip.empty? || line.length <= uri_at

        # Long values can push later columns right, so split the tail on whitespace.
        name = line[0...verb_at].strip
        verb = line[verb_at...uri_at].strip
        path, action = line[uri_at..].strip.split(/\s+/, 2)
        next if path.nil? || !path.start_with?("/")

        normalize({ name: name.empty? ? nil : name, verb: verb, path: path, action: action&.strip })
      end
    end

    def parse_expanded
      routes = []
      current = nil
      @output.each_line do |raw|
        line = raw.chomp
        if HEADER.match?(line.strip)
          routes << current if current
          current = {}
        elsif current && (m = FIELD.match(line))
          key = KEYS[m[1].strip] || m[1].strip.downcase.gsub(/\W+/, "_").to_sym
          value = m[2].strip
          current[key] = value.empty? ? nil : value
        end
      end
      routes << current if current
      routes.map { |r| normalize(r) }
    end

    def normalize(route)
      route[:verb] = route[:verb].to_s.empty? ? nil : route[:verb]
      if route[:action]&.include?("#")
        controller, action = route[:action].split("#", 2)
        route[:controller] = controller
        route[:action] = action.split(/\s/).first
        route[:controller_action] = "#{controller}##{route[:action]}"
      end
      route.compact
    end
  end
end
