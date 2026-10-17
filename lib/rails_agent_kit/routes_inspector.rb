# frozen_string_literal: true

require "open3"
require "rbconfig"
require "shellwords"
require "timeout"

module RailsAgentKit
  # Lists routes for the Rails app at `root`.
  #
  # Listing routes needs a booted app, so this shells out to
  # `bin/rails routes --expanded` in the app's own bundle. When that is
  # not possible (no bin/rails, boot error, timeout) it degrades gracefully:
  # it says why and returns the raw config/routes.rb so the agent can still read it.
  # A pre-generated routes dump can be supplied with `routes_file:` to skip booting.
  class RoutesInspector
    DEFAULT_TIMEOUT = 60

    def initialize(root, routes_file: nil, timeout: nil, command: nil)
      @root = File.expand_path(root)
      @routes_file = routes_file && File.expand_path(routes_file, @root)
      @timeout = (timeout || ENV.fetch("RAILS_AGENT_KIT_ROUTES_TIMEOUT", DEFAULT_TIMEOUT)).to_f
      @command = command
    end

    def call(filter: nil)
      output, source = fetch_output
      routes = RoutesParser.parse(output)
      if routes.empty?
        return fallback("`#{source}` produced no parseable routes " \
                        "(expected `bin/rails routes --expanded` output).")
      end

      matched = apply_filter(routes, filter)
      { source: source, total: routes.size, count: matched.size, routes: matched }
    rescue RoutesUnavailable => e
      fallback(e.message)
    end

    class RoutesUnavailable < StandardError; end

    private

    def fetch_output
      if @routes_file
        raise RoutesUnavailable, "Routes file not found: #{@routes_file}" unless File.file?(@routes_file)

        return [File.read(@routes_file), File.basename(@routes_file)]
      end

      cmd = @command || default_command
      [run(cmd), cmd.join(" ")]
    end

    def default_command
      custom = ENV.fetch("RAILS_AGENT_KIT_ROUTES_COMMAND", "").strip
      return Shellwords.split(custom) unless custom.empty?

      bin_rails = File.join(@root, "bin", "rails")
      raise RoutesUnavailable, "No bin/rails found in #{@root}; cannot boot the app to list routes." unless File.file?(bin_rails)

      [RbConfig.ruby, "bin/rails", "routes", "--expanded"]
    end

    def run(cmd)
      with_app_env do
        Open3.popen3(*cmd, chdir: @root, pgroup: true) do |stdin, stdout, stderr, wait|
          stdin.close
          out_reader = reader(stdout)
          err_reader = reader(stderr)
          unless wait.join(@timeout)
            kill(wait.pid)
            raise RoutesUnavailable, "`#{cmd.join(' ')}` timed out after #{@timeout.to_i}s while booting the app."
          end
          out = out_reader.value
          err = err_reader.value
          unless wait.value.success?
            raise RoutesUnavailable, "`#{cmd.join(' ')}` failed (exit #{wait.value.exitstatus}): #{tail(err.empty? ? out : err)}"
          end
          out
        end
      end
    rescue SystemCallError => e
      raise RoutesUnavailable, "Could not run `#{cmd.join(' ')}`: #{e.message}"
    end

    # Run the app with its own Gemfile, not this gem's bundle.
    def with_app_env(&block)
      if defined?(Bundler) && Bundler.respond_to?(:with_unbundled_env)
        Bundler.with_unbundled_env(&block)
      else
        yield
      end
    end

    def reader(io)
      Thread.new do
        Thread.current.report_on_exception = false
        io.read
      rescue IOError
        ""
      end
    end

    # Kill the whole process group (bin/rails may spawn spring or other children).
    def kill(pid)
      Process.kill("TERM", -pid)
      sleep 0.2
      Process.kill("KILL", -pid)
    rescue SystemCallError
      nil
    end

    def tail(text, lines: 15)
      text.to_s.lines.last(lines).join.strip
    end

    def apply_filter(routes, filter)
      return routes if filter.nil? || filter.to_s.strip.empty?

      needle = filter.to_s.downcase
      routes.select do |r|
        [r[:name], r[:path], r[:controller_action], r[:verb]].compact.any? { |v| v.downcase.include?(needle) }
      end
    end

    def fallback(reason)
      routes_rb = File.join(@root, "config", "routes.rb")
      result = {
        routes_unavailable: true,
        message: "Could not list routes: #{reason} Falling back to the raw config/routes.rb " \
                 "(no route expansion, helpers or engine routes). Tip: run " \
                 "`bin/rails routes --expanded > tmp/routes.txt` and start the server with --routes-file tmp/routes.txt."
      }
      if File.file?(routes_rb)
        result[:fallback_source] = "config/routes.rb"
        result[:routes_rb] = File.read(routes_rb)
      else
        result[:message] += " config/routes.rb was not found either."
      end
      result
    end
  end
end
