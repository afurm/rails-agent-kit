# frozen_string_literal: true

require "rbconfig"
require "rubygems"

module RailsAgentKit
  # Works out which Ruby a Rails app wants and where to find it, without a shell profile.
  #
  # The required version comes from the first of `.ruby-version`, `.tool-versions`, `mise.toml` (or `.mise.toml`)
  # and the Gemfile `ruby` directive, looked up from the app root upwards like rbenv and mise do. If the Ruby running
  # rails-agent-kit satisfies it, that Ruby is used. Otherwise the installs of mise, rbenv, asdf and chruby are
  # searched directly, so this also works when an editor starts the server with a minimal PATH.
  class RubyEnv
    Result = Struct.new(:required_version, :source_file, :manager, :ruby, :version, :found, keyword_init: true) do
      # The command that runs a Ruby script with the app's Ruby, e.g. ["/home/me/.rbenv/versions/3.3.5/bin/ruby"].
      def command_prefix
        found ? [ruby] : []
      end

      def to_h
        { version: version, required: required_version, source: source_file, manager: manager, command: ruby }.compact
      end
    end

    VERSION_FILES = [".ruby-version", ".tool-versions", "mise.toml", ".mise.toml"].freeze
    INSTALL_HINTS = {
      "mise" => "mise install ruby@%s",
      "rbenv" => "rbenv install %s",
      "asdf" => "asdf install ruby %s",
      "chruby" => "ruby-install ruby %s"
    }.freeze

    def self.detect(root, env: ENV)
      new(root, env: env).detect
    end

    def initialize(root, env: ENV, current_ruby: RbConfig.ruby, current_version: RUBY_VERSION)
      @root = File.expand_path(root)
      @env = env
      @current_ruby = current_ruby
      @current_version = current_version
    end

    def detect
      required, source = required_version
      return current(nil, nil) if required.nil?
      return current(required, source) if satisfies?(@current_version, required)

      manager, version, ruby = find_install(required)
      if ruby
        Result.new(required_version: required, source_file: source, manager: manager, ruby: ruby, version: version,
                   found: true)
      else
        Result.new(required_version: required, source_file: source, manager: preferred_manager(source),
                   found: false)
      end
    end

    # The version the app asks for and the file that says so (relative to the app root), or nil.
    def requirement
      required_version
    end

    # A one-line explanation for a Result that wasn't found.
    def self.missing_message(result)
      hint = format(INSTALL_HINTS.fetch(result.manager || "rbenv"), result.required_version.sub(/\A[~><=\s]+/, ""))
      "The app wants Ruby #{result.required_version} (from #{result.source_file}), but it isn't installed. " \
        "Install it with `#{hint}`, or set RAILS_AGENT_KIT_ROUTES_COMMAND."
    end

    private

    def current(required, source)
      Result.new(required_version: required, source_file: source, manager: nil, ruby: @current_ruby,
                 version: @current_version, found: true)
    end

    # Returns [requirement, source file relative to the app root] or nil.
    def required_version
      dir = @root
      loop do
        VERSION_FILES.each do |name|
          path = File.join(dir, name)
          next unless File.file?(path)

          version = parse_version_file(name, File.read(path))
          return [version, relative(path)] if version
        end
        gemfile = File.join(dir, "Gemfile")
        if File.file?(gemfile) && (version = parse_gemfile(File.read(gemfile)))
          return [version, relative(gemfile)]
        end

        parent = File.dirname(dir)
        return nil if parent == dir

        dir = parent
      end
    end

    def parse_version_file(name, text)
      case name
      when ".ruby-version"
        normalize(text.lines.map(&:strip).find { |l| !l.empty? && !l.start_with?("#") })
      when ".tool-versions"
        line = text.lines.map(&:strip).find { |l| l.match?(/\Aruby\s+\S/) }
        line && normalize(line.split[1])
      else
        match = text.match(/^\s*ruby\s*=\s*["']([^"']+)["']/)
        match && normalize(match[1])
      end
    end

    def parse_gemfile(text)
      match = text.match(/^\s*ruby\s*\(?\s*["']([^"']+)["']/)
      match && match[1].strip
    end

    # "ruby-3.3.5" -> "3.3.5". Non-MRI engines (jruby-9.4, truffleruby) and "system" are not handled.
    def normalize(version)
      return nil if version.nil?

      version = version.strip.delete_prefix("ruby-")
      version.match?(/\A\d+(\.\d+)*\z/) ? version : nil
    end

    def satisfies?(candidate, required)
      if required.match?(/\A\s*[~><=!]/)
        Gem::Requirement.new(*required.split(",").map(&:strip)).satisfied_by?(Gem::Version.new(candidate))
      else
        candidate == required || candidate.start_with?("#{required}.")
      end
    rescue ArgumentError
      false
    end

    def preferred_manager(source)
      case File.basename(source.to_s)
      when ".tool-versions" then "asdf"
      when "mise.toml", ".mise.toml" then "mise"
      else installed_managers.first
      end
    end

    def installed_managers
      install_roots.select { |_, dirs| dirs.any? { |d| File.directory?(d) } }.map(&:first)
    end

    # manager => directories that hold one subdirectory per installed Ruby.
    def install_roots
      home = @env["HOME"] || Dir.home
      {
        "mise" => [File.join(@env["MISE_DATA_DIR"] || File.join(home, ".local/share/mise"), "installs/ruby")],
        "rbenv" => [File.join(@env["RBENV_ROOT"] || File.join(home, ".rbenv"), "versions")],
        "asdf" => [File.join(@env["ASDF_DATA_DIR"] || File.join(home, ".asdf"), "installs/ruby")],
        "chruby" => [File.join(home, ".rubies"), "/opt/rubies"]
      }
    end

    # Returns [manager, version, ruby path] for the newest install that satisfies the requirement.
    def find_install(required)
      candidates = install_roots.flat_map do |manager, dirs|
        dirs.flat_map do |dir|
          Dir.glob(File.join(dir, "*", "bin", "ruby")).filter_map do |ruby|
            version = File.basename(File.dirname(File.dirname(ruby))).delete_prefix("ruby-")
            next unless version.match?(/\A\d+(\.\d+)*\z/) && File.executable?(ruby) && !File.symlink?(File.dirname(File.dirname(ruby)))

            [manager, version, ruby] if satisfies?(version, required)
          end
        end
      end
      candidates.max_by { |_, version, _| Gem::Version.new(version) }
    end

    def relative(path)
      path.start_with?("#{@root}/") ? path.delete_prefix("#{@root}/") : path
    end
  end
end
