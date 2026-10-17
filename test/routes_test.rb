# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"

class RoutesTest < Minitest::Test
  include FixtureHelpers

  def blog
    fixture_path("blog_app")
  end

  def test_parser_reads_expanded_format
    routes = RailsAgentKit::RoutesParser.parse(File.read(fixture_path("blog_app", "routes_expanded.txt")))
    assert_equal 7, routes.size
    assert_equal(
      { name: "post_comments", verb: "POST", path: "/posts/:post_id/comments(.:format)", action: "create",
        source_location: "config/routes.rb:3", controller: "comments", controller_action: "comments#create" },
      routes.first
    )
    refute routes[3].key?(:name), "blank prefix should be omitted"
    assert_equal "rails/health", routes[5][:controller]
  end

  # Real `bin/rails routes` output captured from a Rails 8.1 app.
  def test_parser_reads_default_table_format
    routes = RailsAgentKit::RoutesParser.parse(File.read(fixture_path("routes_table.txt")))
    assert_equal 9, routes.size
    assert_equal({ name: "posts", verb: "GET", path: "/posts(.:format)", action: "index",
                   controller: "posts", controller_action: "posts#index" }, routes[0])
    assert_equal({ verb: "POST", path: "/posts(.:format)", action: "create",
                   controller: "posts", controller_action: "posts#create" }, routes[1])
    assert_equal "rails_health_check", routes.last[:name]
    assert_equal "rails/health#show", routes.last[:controller_action]
  end

  def test_boots_app_via_bin_rails
    result = RailsAgentKit::RoutesInspector.new(blog).call
    assert_match(%r{bin/rails routes --expanded}, result[:source])
    assert_equal 7, result[:count]
    assert_equal "posts#index", result[:routes].last[:controller_action]
  end

  def test_custom_command_from_env
    ENV["RAILS_AGENT_KIT_ROUTES_COMMAND"] = "#{RbConfig.ruby} bin/rails routes --expanded"
    result = RailsAgentKit::RoutesInspector.new(blog).call
    assert_equal 7, result[:count]
  ensure
    ENV.delete("RAILS_AGENT_KIT_ROUTES_COMMAND")
  end

  def test_filter
    result = RailsAgentKit::RoutesInspector.new(blog).call(filter: "COMMENTS")
    assert_equal %w[post_comments post_comment], result[:routes].map { |r| r[:name] }
    assert_equal [2, 7], result.values_at(:count, :total)
  end

  def test_routes_file_skips_boot
    result = RailsAgentKit::RoutesInspector.new(blog, routes_file: "routes_expanded.txt",
                                                      command: ["false"]).call
    assert_equal "routes_expanded.txt", result[:source]
    assert_equal 7, result[:count]
  end

  def test_falls_back_without_bin_rails
    result = RailsAgentKit::RoutesInspector.new(fixture_path("sql_app")).call
    assert result[:routes_unavailable]
    assert_match(/No bin\/rails found/, result[:message])
    assert_equal "config/routes.rb", result[:fallback_source]
    assert_includes result[:routes_rb], "resources :accounts"
  end

  def test_falls_back_when_boot_fails
    result = RailsAgentKit::RoutesInspector.new(blog, command: [RbConfig.ruby, "-e", "warn 'LoadError: boom'; exit 1"]).call
    assert result[:routes_unavailable]
    assert_match(/failed \(exit 1\): LoadError: boom/, result[:message])
    assert_includes result[:routes_rb], "resources :posts"
  end

  def test_falls_back_on_timeout
    result = RailsAgentKit::RoutesInspector.new(blog, timeout: 0.5, command: [RbConfig.ruby, "-e", "sleep 10"]).call
    assert result[:routes_unavailable]
    assert_match(/timed out/, result[:message])
  end

  def test_unparseable_output_falls_back
    result = RailsAgentKit::RoutesInspector.new(blog, command: [RbConfig.ruby, "-e", "puts 'Prefix Verb URI'"]).call
    assert result[:routes_unavailable]
    assert_match(/no parseable routes/, result[:message])
  end

  def test_no_routes_rb_either
    Dir.mktmpdir do |dir|
      result = RailsAgentKit::RoutesInspector.new(dir).call
      assert result[:routes_unavailable]
      assert_match(/config\/routes.rb was not found/, result[:message])
    end
  end
end
