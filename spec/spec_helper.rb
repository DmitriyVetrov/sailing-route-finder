# frozen_string_literal: true

# Coverage must start before the library is loaded, or the files loaded earlier are not
# measured. The suite fails below 100% line or branch coverage of lib/.
require "simplecov"
SimpleCov.start do
  enable_coverage :branch
  cover "lib/**/*.rb"
  skip "/spec/"
  coverage :line, minimum: 100
  coverage :branch, minimum: 100
end

require "stringio"
require_relative "../lib/route_finder"

require_relative "support/feed_helpers"
require_relative "support/lowest_rate_resolver"
require_relative "support/toy_graph"
require_relative "support/weight_contract"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end

  config.disable_monkey_patching!

  # Random order exposes hidden dependencies between examples.
  config.order = :random

  config.include FeedHelpers
end
