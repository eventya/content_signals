# frozen_string_literal: true

module ContentSignals
  class Configuration
    attr_accessor :multitenancy,
                  :current_tenant_method,
                  :tenant_model,
                  :redis_enabled,
                  :redis_namespace,
                  :maxmind_db_path,
                  :track_bots,
                  :track_admins,
                  :geoip_provider,  # Symbol (:maxmind, :ipinfo, :null) or a provider class
                  :geoip_token,     # API token for online providers (e.g. IPinfo)
                  :retention_days   # Days to keep raw page_views before purging (default: 90)

    def initialize
      @multitenancy = false
      @current_tenant_method = :current_tenant_id
      @tenant_model = nil
      @redis_enabled = true
      @redis_namespace = "content_signals"
      @maxmind_db_path = default_maxmind_path
      @track_bots = false
      @track_admins = false
      @geoip_provider = :maxmind
      @geoip_token = nil
      @retention_days = 90
    end

    # Returns the resolved provider class for IP geolocation.
    # Accepts a symbol (:maxmind, :ipinfo, :null) or any class that responds to .locate(ip).
    def resolved_geoip_provider
      case @geoip_provider
      when :maxmind then ContentSignals::Geoip::MaxmindProvider
      when :ipinfo  then ContentSignals::Geoip::IpinfoProvider
      when :null    then ContentSignals::Geoip::NullProvider
      when Class    then @geoip_provider
      else
        raise ArgumentError, "Unknown geoip_provider: #{@geoip_provider.inspect}. " \
                             "Use :maxmind, :ipinfo, :null, or a custom provider class."
      end
    end

    def multitenancy?
      @multitenancy
    end

    def redis_enabled?
      @redis_enabled && defined?(Redis)
    end

    private

    def default_maxmind_path
      return nil unless defined?(Rails) && Rails.respond_to?(:root) && Rails.root

      Rails.root.join("db", "GeoLite2-City.mmdb")
    end
  end
end
