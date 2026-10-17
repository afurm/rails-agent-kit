# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "rails_agent_kit"
require "minitest/autorun"

module FixtureHelpers
  FIXTURES = File.expand_path("fixtures", __dir__)

  def fixture_path(*parts)
    File.join(FIXTURES, *parts)
  end
end
