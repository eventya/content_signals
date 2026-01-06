# frozen_string_literal: true

module ContentSignals
  class DeviceDetectorService
    def self.detect(user_agent, app_platform: nil)
      return nil if user_agent.blank?
      return nil unless defined?(Browser)

      browser = Browser.new(user_agent)

      {
        device_type: detect_device_type(browser, app_platform),
        browser: browser.name,
        os: browser.platform.name
      }
    rescue => e
      Rails.logger.error "Device detection error: #{e.message}"
      {
        device_type: app_platform.present? ? 'hybrid_app' : 'desktop',
        browser: 'Unknown',
        os: 'Unknown'
      }
    end

    def self.detect_device_type(browser, app_platform)
      # If it's from a mobile app, always mark as hybrid_app
      return 'hybrid_app' if app_platform.present?

      return 'mobile' if browser.device.mobile?
      return 'tablet' if browser.device.tablet?

      'desktop'
    end

    def self.webview?(user_agent)
      return false if user_agent.blank?

      ua = user_agent.to_s.downcase
      ua.match?(/wv|webview|; wv\)/)
    end
  end
end
