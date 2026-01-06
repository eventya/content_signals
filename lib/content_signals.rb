# frozen_string_literal: true

require_relative "content_signals/version"
require_relative "content_signals/configuration"

module ContentSignals
  class Error < StandardError; end

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end

# Load Rails engine if Rails is available
require_relative "content_signals/engine" if defined?(Rails::Engine)

# Always load models when ActiveRecord is available
if defined?(ActiveRecord)
  require_relative "content_signals/models/page_view"
end

# Load services
require_relative "content_signals/services/page_view_tracker"
require_relative "content_signals/services/visitor_location_service"
require_relative "content_signals/services/device_detector_service"

# Load jobs if ActiveJob is available
if defined?(ActiveJob)
  require_relative "content_signals/jobs/track_page_view_job"
end

# Load concerns if ActiveSupport is available
if defined?(ActiveSupport::Concern)
  require_relative "content_signals/concerns/trackable_page_views"
end
