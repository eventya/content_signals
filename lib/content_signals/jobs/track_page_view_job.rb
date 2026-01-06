# frozen_string_literal: true

module ContentSignals
  class TrackPageViewJob < ActiveJob::Base
    queue_as :default

    # Retry on database errors but not on validation errors
    retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
    discard_on ActiveRecord::RecordInvalid

    def perform(trackable_type, trackable_id, user_id, tracking_data)
      PageView.create!(
        tenant_id: tracking_data['tenant_id'] || tracking_data[:tenant_id],
        trackable_type: trackable_type,
        trackable_id: trackable_id,
        user_id: user_id,
        visitor_id: tracking_data['visitor_id'] || tracking_data[:visitor_id],
        ip_address: tracking_data['ip_address'] || tracking_data[:ip_address],
        user_agent: tracking_data['user_agent'] || tracking_data[:user_agent],
        referrer: tracking_data['referrer'] || tracking_data[:referrer],
        country_code: tracking_data['country_code'] || tracking_data[:country_code],
        country_name: tracking_data['country_name'] || tracking_data[:country_name],
        city: tracking_data['city'] || tracking_data[:city],
        region: tracking_data['region'] || tracking_data[:region],
        latitude: tracking_data['latitude'] || tracking_data[:latitude],
        longitude: tracking_data['longitude'] || tracking_data[:longitude],
        locale: tracking_data['locale'] || tracking_data[:locale],
        device_type: tracking_data['device_type'] || tracking_data[:device_type],
        browser: tracking_data['browser'] || tracking_data[:browser],
        os: tracking_data['os'] || tracking_data[:os],
        app_platform: tracking_data['app_platform'] || tracking_data[:app_platform],
        app_version: tracking_data['app_version'] || tracking_data[:app_version],
        device_id: tracking_data['device_id'] || tracking_data[:device_id],
        viewed_at: tracking_data['viewed_at'] || tracking_data[:viewed_at] || Time.current
      )
    rescue => e
      Rails.logger.error "Failed to track page view: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Optionally send to error tracking service (Sentry, Rollbar, etc.)
      raise unless Rails.env.production? # Re-raise in non-production for debugging
    end
  end
end
