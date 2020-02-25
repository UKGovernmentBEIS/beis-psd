# frozen_string_literal: true

require "webmock/rspec"

RSpec.configure do |config|
  config.include ActiveSupport::Testing::TimeHelpers

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.example_status_persistence_file_path = "examples.txt"

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.filter_run_when_matching :focus

  config.default_formatter = "doc" if config.files_to_run.one?

  config.profile_examples = 10

  config.order = :random

  Kernel.srand config.seed
end
