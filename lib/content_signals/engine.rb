# frozen_string_literal: true

require "rails"
require "active_record"

module ContentSignals
  class Engine < ::Rails::Engine
    isolate_namespace ContentSignals

    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot
      g.factory_bot dir: "spec/factories"
    end

    # Eager load models, services, jobs, concerns
    config.eager_load_paths += %W[
      #{root}/lib/content_signals/models
      #{root}/lib/content_signals/services
      #{root}/lib/content_signals/jobs
      #{root}/lib/content_signals/concerns
    ]

    initializer "content_signals.active_job" do
      config.after_initialize do
        if defined?(ActiveJob)
          require_relative "jobs/track_page_view_job" if File.exist?(File.join(__dir__, "jobs", "track_page_view_job.rb"))
        end
      end
    end
  end
end

