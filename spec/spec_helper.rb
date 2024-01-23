# frozen_string_literal: true

require "bootsnap"
Bootsnap.setup(cache_dir: "tmp/cache")

require "simplecov"
SimpleCov.start

require "pry"
require "bundler"

Bundler.require

require "verse/schema"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.include_chain_clauses_in_custom_matcher_descriptions = true
    c.syntax = :expect
  end

  config.filter_run :focus
  config.run_all_when_everything_filtered = true
end
