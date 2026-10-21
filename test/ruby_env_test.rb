# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "tmpdir"

module RubyEnvHelpers

  # Builds a fake <dir>/<version>/bin/ruby that runs the real Ruby and records that it was used.
  def fake_ruby(dir, version)
    bin = File.join(dir, version, "bin")
    FileUtils.mkdir_p(bin)
    ruby = File.join(bin, "ruby")
    File.write(ruby, "#!/bin/sh\necho #{version} > \"$(dirname \"$0\")/used\"\nexec #{RbConfig.ruby} \"$@\"\n")
    File.chmod(0o755, ruby)
    ruby
  end

  def with_app(files = {})
    Dir.mktmpdir do |tmp|
      app = File.join(tmp, "app")
      home = File.join(tmp, "home")
      FileUtils.mkdir_p([app, home])
      files.each { |name, body| File.write(File.join(app, name), body) }
      yield app, home
    end
  end

  def detect(app, home, version: "3.4.1", **env)
    RailsAgentKit::RubyEnv.new(app, env: { "HOME" => home }.merge(env), current_ruby: "/usr/bin/ruby",
                                    current_version: version).detect
  end

end

class RubyEnvTest < Minitest::Test
  include RubyEnvHelpers

  def test_nothing_pinned_uses_the_current_ruby
    with_app do |app, home|
      result = detect(app, home)
      assert result.found
      assert_nil result.required_version
      assert_nil result.manager
      assert_equal ["/usr/bin/ruby"], result.command_prefix
      assert_equal({ version: "3.4.1", command: "/usr/bin/ruby" }, result.to_h)
    end
  end

  def test_current_ruby_satisfies_ruby_version
    with_app(".ruby-version" => "ruby-3.4\n") do |app, home|
      result = detect(app, home)
      assert result.found
      assert_equal ["3.4", ".ruby-version"], [result.required_version, result.source_file]
      assert_equal ["/usr/bin/ruby"], result.command_prefix
    end
  end

  def test_rbenv_install_for_ruby_version
    with_app(".ruby-version" => "3.3.5\n") do |app, home|
      ruby = fake_ruby(File.join(home, ".rbenv/versions"), "3.3.5")
      result = detect(app, home)
      assert result.found
      assert_equal "rbenv", result.manager
      assert_equal "3.3.5", result.version
      assert_equal [ruby], result.command_prefix
    end
  end

  def test_rbenv_root_env_is_honoured
    with_app(".ruby-version" => "3.3.5") do |app, home|
      custom = File.join(home, "custom-rbenv")
      ruby = fake_ruby(File.join(custom, "versions"), "3.3.5")
      assert_equal [ruby], detect(app, home, "RBENV_ROOT" => custom).command_prefix
    end
  end

  def test_asdf_install_for_tool_versions
    with_app(".tool-versions" => "nodejs 22.1.0\nruby 3.3.5\n") do |app, home|
      ruby = fake_ruby(File.join(home, ".asdf/installs/ruby"), "3.3.5")
      result = detect(app, home)
      assert_equal ["asdf", ".tool-versions", [ruby]], [result.manager, result.source_file, result.command_prefix]
    end
  end

  def test_mise_install_for_mise_toml_picks_newest_match
    with_app("mise.toml" => "[tools]\nnode = \"22\"\nruby = \"3.3\"\n") do |app, home|
      installs = File.join(home, ".local/share/mise/installs/ruby")
      fake_ruby(installs, "3.3.4")
      newest = fake_ruby(installs, "3.3.10")
      fake_ruby(installs, "3.4.0")
      result = detect(app, home)
      assert_equal ["mise", "3.3.10", [newest]], [result.manager, result.version, result.command_prefix]
    end
  end

  def test_chruby_install_for_gemfile_requirement
    with_app("Gemfile" => "source \"https://rubygems.org\"\nruby \"~> 3.3.0\"\ngem \"rails\"\n") do |app, home|
      ruby = fake_ruby(File.join(home, ".rubies"), "ruby-3.3.6")
      result = detect(app, home, version: "3.4.1")
      assert_equal ["~> 3.3.0", "Gemfile", "chruby", "3.3.6", [ruby]],
                   [result.required_version, result.source_file, result.manager, result.version, result.command_prefix]
    end
  end

  def test_version_file_in_a_parent_directory
    with_app do |app, home|
      File.write(File.join(File.dirname(app), ".ruby-version"), "3.3.5\n")
      fake_ruby(File.join(home, ".rbenv/versions"), "3.3.5")
      result = detect(app, home)
      assert_equal "rbenv", result.manager
      assert_equal File.join(File.dirname(app), ".ruby-version"), result.source_file
    end
  end

  def test_missing_ruby_is_reported_with_an_install_hint
    with_app(".tool-versions" => "ruby 3.1.9\n") do |app, home|
      result = detect(app, home)
      refute result.found
      assert_empty result.command_prefix
      message = RailsAgentKit::RubyEnv.missing_message(result)
      assert_equal "The app wants Ruby 3.1.9 (from .tool-versions), but it isn't installed. Install it with " \
                   "`asdf install ruby 3.1.9`, or set RAILS_AGENT_KIT_ROUTES_COMMAND.", message
    end
  end

  def test_ignores_engines_it_cannot_resolve
    with_app(".ruby-version" => "jruby-9.4.8.0\n") do |app, home|
      result = detect(app, home)
      assert result.found
      assert_nil result.required_version
    end
  end
end

class RoutesWithAppRubyTest < Minitest::Test
  include FixtureHelpers
  include RubyEnvHelpers
  def blog_copy(dir)
    FileUtils.cp_r(File.join(fixture_path("blog_app"), "."), dir)
    dir
  end

  def test_routes_run_with_the_apps_ruby
    with_app(".ruby-version" => "3.3.5\n") do |app, home|
      blog_copy(app)
      ruby = fake_ruby(File.join(home, ".rbenv/versions"), "3.3.5")
      result = RailsAgentKit::RoutesInspector.new(app, ruby_env: detect(app, home)).call

      assert_equal 7, result[:count]
      assert_equal "#{ruby} bin/rails routes --expanded", result[:source]
      assert_equal({ version: "3.3.5", required: "3.3.5", source: ".ruby-version", manager: "rbenv", command: ruby },
                   result[:ruby])
      assert_equal "3.3.5", File.read(File.join(File.dirname(ruby), "used")).strip
    end
  end

  def test_missing_ruby_falls_back_with_a_clear_message
    with_app(".ruby-version" => "3.1.9\n") do |app, home|
      blog_copy(app)
      FileUtils.mkdir_p(File.join(home, ".rbenv/versions"))
      result = RailsAgentKit::RoutesInspector.new(app, ruby_env: detect(app, home)).call
      assert result[:routes_unavailable]
      assert_match(/The app wants Ruby 3\.1\.9 \(from \.ruby-version\), but it isn't installed\. Install it with `rbenv install 3\.1\.9`/,
                   result[:message])
      assert_includes result[:routes_rb], "resources :posts"
    end
  end

  def test_routes_command_env_overrides_detection
    with_app(".ruby-version" => "3.1.9\n") do |app, home|
      blog_copy(app)
      ENV["RAILS_AGENT_KIT_ROUTES_COMMAND"] = "#{RbConfig.ruby} bin/rails routes --expanded"
      result = RailsAgentKit::RoutesInspector.new(app, ruby_env: detect(app, home)).call
      assert_equal 7, result[:count]
      refute result.key?(:ruby)
    ensure
      ENV.delete("RAILS_AGENT_KIT_ROUTES_COMMAND")
    end
  end
end
