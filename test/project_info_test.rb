# frozen_string_literal: true

require "test_helper"
require "json"
require "tmpdir"

# The fixtures under test/fixtures/project_info are trimmed copies of real `rails new` apps (Rails 8.1).
class ProjectInfoTest < Minitest::Test
  include FixtureHelpers

  def info(name)
    RailsAgentKit::ProjectInfo.new(fixture_path("project_info/#{name}")).call
  end

  def test_default_rails_8_app
    result = info("rails8_default")

    assert_equal "8.1.4", result[:rails]
    assert_equal({ version: "4.0.7", source: ".ruby-version" }, result[:ruby])
    assert_equal "8.1", result[:load_defaults]
    assert_equal false, result[:api_only]
    assert_equal({ adapter: "sqlite3", databases: { "production" => %w[primary cache queue cable] } }, result[:database])
    assert_equal({ framework: "minitest", data: "fixtures", system: "capybara" }, result[:test])
    assert_equal "rails_authentication", result[:auth]
    assert_nil result[:authorization]
    assert_equal %w[solid_queue solid_cache solid_cable], result.values_at(:jobs, :cache, :cable)
    assert_equal({ js: "importmap", assets: "propshaft", hotwire: %w[turbo stimulus], css: nil, views: nil },
                 result[:frontend])
    assert_equal "jbuilder", result[:serializers]
    assert_equal false, result[:graphql]
    assert_includes result[:quality], "rubocop-rails-omakase"
    assert_includes result[:quality], "brakeman"
    assert_equal %w[kamal docker], result[:deploy]
    assert_nil result[:engines]
    assert_equal({ tests: "test", fixtures: "test/fixtures" }, result[:paths])
  end

  def test_rspec_devise_pundit_sidekiq_app
    result = info("rspec_devise")

    assert_equal "postgresql", result[:database][:adapter]
    assert_equal({ framework: "rspec", data: "factory_bot", system: nil }, result[:test])
    assert_equal "devise", result[:auth]
    assert_equal "pundit", result[:authorization]
    assert_equal "sidekiq", result[:jobs], "the configured queue adapter wins over the solid_queue gem"
    assert_equal "tailwind", result[:frontend][:css]
    assert_equal "view_component", result[:frontend][:views]
    assert_equal [{ engine: "Sidekiq::Web", at: "/sidekiq" }], result[:engines]
    assert_equal "43.8.1", result[:gems]["pagy"]
    assert_includes result[:deploy], "procfile"
    assert_equal({ tests: "spec", factories: "spec/factories", policies: "app/policies", components: "app/components" },
                 result[:paths])
  end

  def test_api_only_app
    result = info("api_only")

    assert_equal true, result[:api_only]
    assert_nil result[:frontend]
    assert_equal "alba", result[:serializers]
    assert_equal({ framework: "minitest", data: nil, system: nil }, result[:test])
    assert_nil result[:auth]
  end

  def test_stays_compact
    %w[rails8_default rspec_devise api_only].each do |name|
      assert_operator JSON.generate(info(name)).bytesize, :<, 3 * 1024, "#{name} answer is too large"
    end
  end

  def test_lists_the_files_it_read
    assert_equal "Gemfile.lock", info("rails8_default")[:sources].first
    assert_includes info("rails8_default")[:sources], "config/database.yml"
  end

  def test_unknown_values_are_nil
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Gemfile"), "source \"https://rubygems.org\"\ngem \"rails\"\n")
      result = RailsAgentKit::ProjectInfo.new(dir).call

      assert_nil result[:rails], "no lockfile, so no version"
      %i[ruby load_defaults api_only database auth jobs cache cable engines].each do |key|
        assert_nil result[key], "#{key} should be nil"
      end
      assert_equal({ framework: nil, data: nil, system: nil }, result[:test])
    end
  end

  def test_several_libraries_are_listed
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Gemfile"), "gem \"pundit\"\ngem \"cancancan\"\n")
      File.write(File.join(dir, "Gemfile.lock"), <<~LOCK)
        GEM
          remote: https://rubygems.org/
          specs:
            pundit (2.5.2)
            cancancan (3.6.1)
            nokogiri (1.18.10-x86_64-linux-gnu)

        DEPENDENCIES
          cancancan
          pundit (~> 2.5)

        RUBY VERSION
           ruby 3.3.6p108
      LOCK
      result = RailsAgentKit::ProjectInfo.new(dir).call

      assert_equal %w[pundit cancancan], result[:authorization]
      assert_equal({ version: "3.3.6", source: "Gemfile.lock" }, result[:ruby])
    end
  end

  def test_not_a_rails_app
    Dir.mktmpdir do |dir|
      assert_match(/doesn't look like a Rails app/, RailsAgentKit::ProjectInfo.new(dir).call[:error])
    end
  end
end
