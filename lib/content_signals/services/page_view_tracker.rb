# frozen_string_literal: true

module ContentSignals
  class PageViewTracker
    def self.track(trackable:, request:, user: nil)
      new(trackable, request, user).track
    end

    def initialize(trackable, request, user)
      @trackable = trackable
      @user = user
      @request = request
      @visitor_id = identify_visitor
    end

    def track
      # Track unique view if first time today (optional, requires Redis)
      track_unique_view if unique_today?

      # Gather all tracking data
      tracking_data = compile_tracking_data

      # Store detailed view record asynchronously
      # Note: counter_cache on PageView model will automatically increment page_views_count
      ContentSignals::TrackPageViewJob.perform_later(
        @trackable.class.name,
        @trackable.id,
        @user&.id,
        tracking_data
      )
    end

    private

    def identify_visitor
      # 1. Authenticated user (most reliable)
      return "user_#{@user.id}" if @user

      # 2. Device ID from mobile app (persistent across app sessions)
      device_id = @request.headers['X-Device-ID'] || @request.params[:device_id]
      return "device_#{device_id}" if device_id.present?

      # 3. Browser cookie (works for web, not reliable in WebViews)
      cookie_id = @request.cookie_jar.signed[:visitor_id] if @request.respond_to?(:cookie_jar)
      return cookie_id if cookie_id.present?

      # 4. Fallback to IP + User Agent hash
      "anon_#{Digest::SHA256.hexdigest("#{@request.ip}:#{@request.user_agent}")[0..15]}"
    end

    def unique_today?
      return true unless redis_enabled?

      key = unique_view_key
      !Rails.cache.exist?(key)
    end

    def track_unique_view
      return unless redis_enabled?

      key = unique_view_key
      Rails.cache.write(key, true, expires_in: 24.hours)

      # Also increment daily unique counter
      daily_key = "page_unique_views:#{@trackable.class.name}:#{@trackable.id}:#{Date.current}"
      Rails.cache.increment(daily_key, 1)
    rescue => e
      Rails.logger.error "Failed to track unique view: #{e.message}"
    end

    def unique_view_key
      tenant_part = current_tenant_id ? "tenant_#{current_tenant_id}:" : ""
      "page_view:#{tenant_part}#{@trackable.class.name}:#{@trackable.id}:visitor_#{@visitor_id}:#{Date.current}"
    end

    def compile_tracking_data
      location_data = ContentSignals::VisitorLocationService.locate(@request.ip) || {}
      app_context = detect_app_context
      device_data = ContentSignals::DeviceDetectorService.detect(
        @request.user_agent,
        app_platform: app_context[:app_platform]
      ) || {}

      {
        tenant_id: current_tenant_id,
        visitor_id: @visitor_id,
        ip_address: @request.ip,
        user_agent: @request.user_agent,
        referrer: @request.referrer,
        locale: detect_locale,
        viewed_at: Time.current,
        app_platform: app_context[:app_platform],
        app_version: app_context[:app_version],
        device_id: app_context[:device_id]
      }.merge(location_data).merge(device_data)
    end

    def detect_app_context
      {
        app_platform: @request.headers['X-App-Platform'] || detect_platform_from_ua,
        app_version: @request.headers['X-App-Version'],
        device_id: @request.headers['X-Device-ID'] || @request.params[:device_id]
      }
    end

    def detect_platform_from_ua
      ua = @request.user_agent.to_s.downcase
      return 'capacitor' if ua.include?('capacitor')
      return 'cordova' if ua.include?('cordova')
      return 'react_native' if ua.include?('react-native')
      return 'flutter' if ua.include?('flutter')
      return 'webview' if ua.match?(/wv|webview/)
      nil
    end

    def detect_locale
      accept_language = @request.headers['Accept-Language']
      return I18n.locale.to_s unless accept_language

      accept_language.split(',').first&.strip || I18n.locale.to_s
    end

    def current_tenant_id
      return nil unless ContentSignals.configuration.multitenancy?

      method_name = ContentSignals.configuration.current_tenant_method
      return nil unless method_name

      # Try to get tenant_id from controller instance
      controller = @request.env['action_controller.instance']
      return nil unless controller

      controller.send(method_name) if controller.respond_to?(method_name, true)
    rescue => e
      Rails.logger.error "Failed to get tenant_id: #{e.message}"
      nil
    end

    def redis_enabled?
      ContentSignals.configuration.redis_enabled? && Rails.cache.respond_to?(:redis)
    rescue
      false
    end
  end
end
