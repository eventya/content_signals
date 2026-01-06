# frozen_string_literal: true

module ContentSignals
  module TrackablePageViews
    extend ActiveSupport::Concern

    included do
      after_action :track_page_view, only: [:show]
    end

    private

    def track_page_view
      return if should_skip_tracking?

      trackable = find_trackable_for_tracking
      return unless trackable

      PageViewTracker.track(
        trackable: trackable,
        user: current_user_for_tracking,
        request: request
      )
    rescue => e
      Rails.logger.error "Failed to track page view: #{e.message}"
      # Don't raise - tracking failures shouldn't break the request
    end

    def should_skip_tracking?
      bot_request? ||
      admin_viewing? ||
      preview_mode?
    end

    def find_trackable_for_tracking
      # Look for common instance variable names
      # Override this method in your controller if you use different naming
      @page || @post || @article || @profile || @event || @trackable
    end

    def current_user_for_tracking
      # Override this method if you use a different method name
      current_user if respond_to?(:current_user, true)
    end

    def bot_request?
      return false unless defined?(Browser)

      browser = Browser.new(request.user_agent)
      browser.bot? || browser.search_engine?
    rescue
      false
    end

    def admin_viewing?
      user = current_user_for_tracking
      return false unless user

      # Check common admin patterns
      user.respond_to?(:admin?) && user.admin?
    rescue
      false
    end

    def preview_mode?
      params[:preview].present? || session[:preview_mode]
    rescue
      false
    end
  end
end
