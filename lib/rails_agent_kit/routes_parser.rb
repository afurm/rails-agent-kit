# frozen_string_literal: true

module RailsAgentKit
  # Parses the output of `bin/rails routes --expanded` (preferred) or the
  # default table output of `bin/rails routes`.
  #
  # Routes of a mounted engine are listed after a `[ Routes for Blorgh::Engine ]` (expanded) or
  # `Routes for Blorgh::Engine:` (table) line and get `engine` and, when the mount is found, `mounted_at`,
  # because their paths are relative to where the engine is mounted.
  class RoutesParser
    HEADER = /\A--\[\s*Route\s+\d+\s*\]-*\s*\z/
    SECTION = /\A\[?\s*Routes for (\S+?)\s*(?:\]|:)\s*\z/
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
      engine = nil
      routes = lines.drop(lines.index(header) + 1).filter_map do |line|
        if (m = SECTION.match(line.strip))
          engine = m[1] == "application" ? nil : m[1]
          next
        end
        next if line.strip.empty? || line.length <= uri_at

        # Long values can push later columns right, so split the tail on whitespace.
        name = line[0...verb_at].strip
        verb = line[verb_at...uri_at].strip
        path, action = line[uri_at..].strip.split(/\s+/, 2)
        next if path.nil? || !path.start_with?("/")

        route = { name: name.empty? ? nil : name, verb: verb, path: path, action: action&.strip }
        route[:engine] = engine if engine
        normalize(route)
      end
      add_mount_points(routes)
    end

    def parse_expanded
      routes = []
      current = nil
      engine = nil
      @output.each_line do |raw|
        line = raw.chomp
        if (m = SECTION.match(line.strip))
          routes << current if current
          current = nil
          engine = m[1] == "application" ? nil : m[1]
        elsif HEADER.match?(line.strip)
          routes << current if current
          current = engine ? { engine: engine } : {}
        elsif current && (m = FIELD.match(line))
          key = KEYS[m[1].strip] || m[1].strip.downcase.gsub(/\W+/, "_").to_sym
          value = m[2].strip
          current[key] = value.empty? ? nil : value
        end
      end
      routes << current if current
      add_mount_points(routes.map { |r| normalize(r) })
    end

    # The app route that mounts an engine has the engine's class name as its action, e.g. `Blorgh::Engine`.
    def add_mount_points(routes)
      mounts = routes.each_with_object({}) do |r, h|
        h[r[:action]] ||= r[:path] if !r[:engine] && r[:action]&.end_with?("::Engine")
      end
      routes.each { |r| r[:mounted_at] = mounts[r[:engine]] if r[:engine] && mounts[r[:engine]] }
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
