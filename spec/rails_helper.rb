# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

# Minimal Rails setup for testing
require "active_record"
require "active_job"

# Configure ActiveJob to use test adapter (prevents actual job execution)
ActiveJob::Base.queue_adapter = :test

# Load the gem
require "content_signals"

# Stub Rails if not already defined
unless defined?(Rails)
  class Rails
    def self.logger
      @logger ||= Logger.new($stdout)
    end

    def self.cache
      @cache ||= ActiveSupport::Cache::MemoryStore.new
    end

    def self.env
      @env ||= ActiveSupport::StringInquirer.new('test')
    end

    def self.root
      @root ||= Pathname.new(File.expand_path('../..', __dir__))
    end
  end
end

# Ensure all components are loaded
require_relative "../lib/content_signals/models/page_view"
require_relative "../lib/content_signals/jobs/track_page_view_job"
require_relative "../lib/content_signals/services/page_view_tracker"
require_relative "../lib/content_signals/services/visitor_location_service"
require_relative "../lib/content_signals/services/device_detector_service"
require_relative "../lib/content_signals/concerns/trackable_page_views"

# Set up test database
ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:"
)

# Load database schema
require_relative "support/schema"

# Load support files
Dir[File.join(__dir__, "support", "**", "*.rb")].sort.each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Clean database between tests
  config.around(:each) do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end

  # Reset configuration between tests
  config.before(:each) do
    ContentSignals.reset_configuration!
  end

  # Use color in output
  config.color = true

  # Use documentation format
  config.default_formatter = "doc" if config.files_to_run.one?

  # Order tests randomly
  config.order = :random
  Kernel.srand config.seed
end
