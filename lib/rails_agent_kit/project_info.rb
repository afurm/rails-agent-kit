# frozen_string_literal: true

require "erb"
require "yaml"

module RailsAgentKit
  # Answers "what kind of Rails app is this?" from Gemfile.lock, config files and the directory layout, without
  # booting the app. Every value comes from a file in the app; anything that can't be read from one is nil.
  class ProjectInfo
    # [field, gem or detector => reported name]. The first matching entries win, in this order.
    CHOICES = {
      js: { "importmap-rails" => "importmap", "jsbundling-rails" => "jsbundling", "vite_rails" => "vite",
            "vite_ruby" => "vite", "shakapacker" => "shakapacker", "webpacker" => "webpacker" },
      assets: { "propshaft" => "propshaft", "sprockets-rails" => "sprockets", "sprockets" => "sprockets" },
      css: { "tailwindcss-rails" => "tailwind", "cssbundling-rails" => "cssbundling", "dartsass-rails" => "sass",
             "sassc-rails" => "sass", "bootstrap" => "bootstrap" },
      views: { "view_component" => "view_component", "phlex-rails" => "phlex" },
      serializers: { "jbuilder" => "jbuilder", "alba" => "alba", "blueprinter" => "blueprinter",
                     "active_model_serializers" => "active_model_serializers",
                     "jsonapi-serializer" => "jsonapi-serializer", "oj_serializers" => "oj_serializers" },
      authorization: { "pundit" => "pundit", "cancancan" => "cancancan", "action_policy" => "action_policy" },
      auth_gems: { "devise" => "devise", "rodauth-rails" => "rodauth", "sorcery" => "sorcery",
                   "clearance" => "clearance" },
      job_gems: { "solid_queue" => "solid_queue", "sidekiq" => "sidekiq", "good_job" => "good_job",
                  "resque" => "resque", "delayed_job_active_record" => "delayed_job" },
      factories: { "factory_bot_rails" => "factory_bot", "factory_bot" => "factory_bot", "fabrication" => "fabrication" }
    }.freeze
    HOTWIRE = { "turbo-rails" => "turbo", "stimulus-rails" => "stimulus" }.freeze
    QUALITY = %w[rubocop-rails-omakase standard rubocop rubocop-rails brakeman bundler-audit erb_lint herb].freeze
    NOTABLE = %w[
      pagy kaminari will_paginate ransack pg_search searchkick paper_trail audited logidze friendly_id aasm
      money-rails noticed flipper rack-attack strong_migrations annotaterb annotate image_processing aws-sdk-s3
      stripe pay mission_control-jobs activeadmin administrate avo rolify discard paranoia acts_as_list ancestry
      store_model sentry-ruby honeybadger rollbar appsignal skylight lograge solid_errors
    ].freeze
    PATHS = {
      tests: %w[spec test], factories: %w[spec/factories test/factories], fixtures: %w[spec/fixtures test/fixtures],
      policies: %w[app/policies], components: %w[app/components app/views/components],
      serializers: %w[app/serializers app/blueprints app/resources], services: %w[app/services],
      graphql: %w[app/graphql], javascript: %w[app/javascript]
    }.freeze

    def initialize(root)
      @root = File.expand_path(root)
      @sources = []
    end

    def call
      unless file?("Gemfile") || file?("config/application.rb")
        return { error: "No Gemfile or config/application.rb in #{@root}, so this doesn't look like a Rails app." }
      end

      @specs, @deps = read_lockfile
      info = {
        rails: @specs["rails"] || @specs["railties"],
        ruby: ruby,
        load_defaults: application_rb&.[](/^\s*config\.load_defaults\s+["']?([\d.]+)/, 1),
        api_only: application_rb ? application_rb.match?(/^\s*config\.api_only\s*=\s*true/) : nil,
        database: database,
        test: test_stack,
        auth: auth,
        authorization: pick(:authorization),
        jobs: jobs,
        cache: cache,
        cable: cable,
        frontend: frontend,
        serializers: pick(:serializers),
        graphql: gem?("graphql"),
        quality: presence(QUALITY.select { |g| gem?(g) }),
        deploy: deploy,
        engines: engines,
        gems: presence(NOTABLE.select { |g| gem?(g) }.to_h { |g| [g, @specs[g]] }),
        paths: presence(paths)
      }
      info[:sources] = @sources.uniq
      info
    end

    private

    # Gemfile.lock specs (name => version) and direct dependencies. Without a lockfile, the Gemfile's gem lines.
    def read_lockfile
      text = read("Gemfile.lock")
      if text.nil?
        gemfile = read("Gemfile").to_s
        names = gemfile.scan(/^\s*gem\s+["']([^"']+)["']/).flatten
        return [names.to_h { |n| [n, nil] }, names]
      end

      specs = {}
      deps = []
      section = nil
      text.each_line do |line|
        section = line.strip if line.match?(/\A[A-Z]/)
        if section == "GEM" && (m = line.match(/\A {4}([^\s(]+) \(([^)]+)\)\s*\z/))
          specs[m[1]] ||= m[2].sub(/-(?:x86|arm|aarch|universal|java|x64|mingw).*\z/, "")
        elsif section == "DEPENDENCIES" && (m = line.match(/\A {2}([^\s(!]+)/))
          deps << m[1]
        end
      end
      [specs, deps]
    end

    def gem?(name)
      @deps.include?(name) || (@deps.empty? && @specs.key?(name))
    end

    def pick(field, choices = CHOICES.fetch(field))
      found = choices.select { |gem, _| gem?(gem) }.values.uniq
      found.size > 1 ? found : found.first
    end

    def ruby
      env = RubyEnv.new(@root)
      required, source = env.requirement
      if required.nil? && (lock = read("Gemfile.lock")) && (m = lock.match(/^RUBY VERSION\n\s+ruby ([\d.]+)/))
        required = m[1]
        source = "Gemfile.lock"
      end
      return nil if required.nil?

      @sources << source
      { version: required, source: source }
    end

    def application_rb
      return @application_rb if defined?(@application_rb)

      @application_rb = read("config/application.rb")
    end

    def production_rb
      return @production_rb if defined?(@production_rb)

      @production_rb = read("config/environments/production.rb")
    end

    def database
      config = yaml("config/database.yml")
      return nil unless config.is_a?(Hash)

      adapters = []
      multi = {}
      config.each do |env, value|
        next unless value.is_a?(Hash) && env != "default"

        if value.key?("adapter") || value.key?("database") || value.key?("url")
          adapters << value["adapter"]
        else
          dbs = value.select { |_, db| db.is_a?(Hash) }
          adapters.concat(dbs.values.map { |db| db["adapter"] })
          multi[env] = dbs.keys if dbs.size > 1
        end
      end
      adapters = adapters.compact.uniq
      { adapter: adapters.size > 1 ? adapters : adapters.first, databases: presence(multi) }.compact
    end

    def test_stack
      framework = if file?("spec/rails_helper.rb") || file?("spec/spec_helper.rb") then "rspec"
                  elsif file?("test/test_helper.rb") then "minitest"
                  elsif gem?("rspec-rails") then "rspec"
                  end
      data = pick(:factories)
      data ||= "fixtures" if Dir.glob(File.join(@root, "{test,spec}/fixtures/**/*.yml")).any?
      system = gem?("capybara") ? "capybara" : nil
      system ||= "cuprite" if gem?("cuprite")
      { framework: framework, data: data, system: system }
    end

    def auth
      found = []
      if file?("app/controllers/concerns/authentication.rb") && file?("app/models/session.rb")
        found << "rails_authentication"
      end
      found.concat(CHOICES[:auth_gems].select { |gem, _| gem?(gem) }.values)
      found.size > 1 ? found : found.first
    end

    def jobs
      configured = [production_rb, application_rb].compact.filter_map do |text|
        text[/^\s*config\.active_job\.queue_adapter\s*=\s*:(\w+)/, 1]
      end.first
      configured || pick(:job_gems)
    end

    def cache
      production_rb&.[](/^\s*config\.cache_store\s*=\s*:(\w+?)(?:_store)?\b/, 1)
    end

    def cable
      config = yaml("config/cable.yml")
      config.is_a?(Hash) && config["production"].is_a?(Hash) ? config["production"]["adapter"] : nil
    end

    def frontend
      return nil if application_rb&.match?(/^\s*config\.api_only\s*=\s*true/) && pick(:js).nil?

      hotwire = HOTWIRE.select { |gem, _| gem?(gem) }.values
      @sources << "config/importmap.rb" if file?("config/importmap.rb")
      { js: pick(:js), assets: pick(:assets), hotwire: presence(hotwire), css: pick(:css), views: pick(:views) }
    end

    def deploy
      found = []
      found << "kamal" if file?("config/deploy.yml") || gem?("kamal")
      found << "docker" if file?("Dockerfile")
      found << "procfile" if file?("Procfile")
      found << "fly" if file?("fly.toml")
      found << "render" if file?("render.yaml")
      found << "heroku" if file?("app.json")
      presence(found)
    end

    # `mount Engine => "/path"` and `mount Engine, at: "/path"` lines in config/routes.rb.
    def engines
      routes = read("config/routes.rb")
      return nil if routes.nil?

      mounts = routes.scan(/^\s*mount\s+([A-Z][\w:]*(?:\.\w+)?)\s*(?:=>|,\s*at:)\s*["']([^"']+)["']/)
      presence(mounts.map { |engine, at| { engine: engine, at: at } })
    end

    def paths
      PATHS.filter_map do |key, candidates|
        dir = candidates.find { |path| File.directory?(File.join(@root, path)) }
        [key, dir] if dir
      end.to_h
    end

    def yaml(path)
      text = read(path)
      return nil if text.nil?

      YAML.safe_load(text.gsub(/<%.*?%>/m, "erb"), aliases: true)
    rescue Psych::Exception
      nil
    end

    def file?(path)
      File.file?(File.join(@root, path))
    end

    def read(path)
      full = File.join(@root, path)
      return nil unless File.file?(full)

      @sources << path
      File.read(full)
    end

    def presence(value)
      value.nil? || value.empty? ? nil : value
    end
  end
end
