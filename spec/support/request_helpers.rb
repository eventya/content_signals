# frozen_string_literal: true

# Mock request object for testing
class MockRequest
  attr_accessor :ip, :user_agent, :referrer, :headers, :params, :cookie_jar, :env

  def initialize(attributes = {})
    @ip = attributes[:ip] || "1.2.3.4"
    @user_agent = attributes[:user_agent] || "Mozilla/5.0"
    @referrer = attributes[:referrer]
    @headers = attributes[:headers] || {}
    @params = attributes[:params] || {}
    @cookie_jar = MockCookieJar.new(attributes[:cookies] || {})
    @env = attributes[:env] || {}
  end
end

class MockCookieJar
  def initialize(cookies = {})
    @cookies = cookies
  end

  def signed
    self
  end

  def [](key)
    value = @cookies[key]
    # If it's a hash with :value key (Rails cookie format), return just the value
    value.is_a?(Hash) && value.key?(:value) ? value[:value] : value
  end

  def []=(key, value)
    @cookies[key] = value
  end

  # Allow tests to access the full cookie data including options
  def cookie_data(key)
    @cookies[key]
  end
end

# Helper methods for specs
module RequestHelpers
  def mock_request(**attributes)
    MockRequest.new(attributes)
  end

  def mock_web_request
    MockRequest.new(
      ip: "8.8.8.8",
      user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    )
  end

  def mock_mobile_request
    MockRequest.new(
      ip: "8.8.8.8",
      user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    )
  end

  def mock_hybrid_app_request(platform: "capacitor", device_id: "device123", app_version: "1.0.0")
    MockRequest.new(
      ip: "8.8.8.8",
      user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
      headers: {
        "X-App-Platform" => platform,
        "X-Device-ID" => device_id,
        "X-App-Version" => app_version
      }
    )
  end
end

RSpec.configure do |config|
  config.include RequestHelpers
end
