# frozen_string_literal: true

source "https://rubygems.org"

group :test do
  gem "rspec", "~> 3.13"
  gem "simplecov", "~> 1.3", require: false
end

# Local debugging only (rdbg, binding.break); the solution does not use it.
group :development do
  gem "debug"
end

# Exact money arithmetic. Pinned to the version bundled with Ruby 3.3, so there is one
# version at runtime; it has a native extension, compiled in the Dockerfile's builder stage.
gem "bigdecimal", "3.1.5"
