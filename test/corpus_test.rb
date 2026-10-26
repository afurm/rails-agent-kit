# frozen_string_literal: true

require_relative "test_helper"
require "json"

# Checks the parsers against real schemas and route listings: `rails new` apps for each supported Rails
# version and database (test/corpus/apps), plus large open-source schemas fetched by
# script/corpus/fetch_external. Expected counts come from the booted apps and from PostgreSQL itself; see
# test/corpus/README.md.
class CorpusTest < Minitest::Test
  CORPUS = File.expand_path("corpus", __dir__)
  EXTERNAL_DIR = File.expand_path("../tmp/corpus/external", __dir__)

  def self.apps
    Dir[File.join(CORPUS, "apps", "*")].select { |d| File.directory?(d) }.sort
  end

  def self.external_sources
    JSON.parse(File.read(File.join(CORPUS, "external.json")))["sources"]
  end

  def test_corpus_covers_every_supported_rails_version_and_database
    names = self.class.apps.map { |d| File.basename(d) }
    %w[7.2 8.0 8.1].product(%w[sqlite3 postgresql]).each do |version, db|
      assert_includes names, "rails-#{version}-#{db}"
    end
  end

  apps.each do |dir|
    name = File.basename(dir).tr(".-", "__")

    define_method(:"test_schema_#{name}") do
      expected = JSON.parse(File.read(File.join(dir, "expected.json")))
      result = RailsAgentKit::SchemaParser.parse_file(File.join(dir, "schema.rb"))
      assert_schema_matches expected["schema"], result
      assert_empty result.warnings
    end

    define_method(:"test_routes_#{name}") do
      expected = JSON.parse(File.read(File.join(dir, "expected.json")))["routes"]
      routes = RailsAgentKit::RoutesParser.parse(File.read(File.join(dir, "routes_expanded.txt")))

      assert_equal expected["routes"], routes.size
      expected["engines"].each do |engine, count|
        engine_routes = routes.select { |r| r[:engine] == engine }
        assert_equal count, engine_routes.size, "routes for #{engine}"
        assert(engine_routes.all? { |r| r[:mounted_at] }, "#{engine} routes know where they are mounted")
      end
      assert_route routes, "new_account_session", "devise/sessions#new"
      assert(routes.any? { |r| r[:path] == "/sidekiq" && r[:action] == "Sidekiq::Web" }, "Sidekiq::Web mount")
      assert(routes.any? { |r| r[:controller].to_s.start_with?("active_storage/") }, "Active Storage routes")
      assert_route routes, "admin_reports", "admin/reports#index"
    end
  end

  external_sources.each do |source|
    define_method(:"test_external_schema_#{source['name']}") do
      path = File.join(EXTERNAL_DIR, "#{source['name']}.schema.rb")
      unless File.file?(path)
        flunk "#{path} is missing; run script/corpus/fetch_external" if ENV["CORPUS_REQUIRED"]
        skip "run script/corpus/fetch_external to test against the #{source['name']} schema"
      end

      expected = JSON.parse(File.read(File.join(CORPUS, "external", "#{source['name']}.expected.json")))
      result = RailsAgentKit::SchemaParser.parse_file(path)
      assert_schema_matches expected, result
      assert_equal Array(expected["views"]), result.views.map { |v| v[:name] }.sort

      allowed = Array(source["expected_warnings"])
      result.warnings.each do |w|
        assert(allowed.any? { |prefix| w[:statement].start_with?(prefix) }, "unexpected warning: #{w.inspect}")
      end
    end
  end

  private

  def assert_schema_matches(expected, result)
    actual = result.tables.reject { |t| t[:virtual] }.to_h { |t| [t[:name], t[:columns].size] }
    missing = expected["tables"].keys - actual.keys
    extra = actual.keys - expected["tables"].keys
    assert_empty missing, "tables the parser missed"
    assert_empty extra, "tables the parser invented"
    expected["tables"].each do |table, count|
      assert_equal count, actual[table], "column count of #{table}"
    end
  end

  def assert_route(routes, name, controller_action)
    route = routes.find { |r| r[:name] == name }
    assert route, "route #{name}"
    assert_equal controller_action, route[:controller_action]
  end
end
