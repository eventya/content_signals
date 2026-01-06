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
                  :track_admins

    def initialize
      @multitenancy = false
      @current_tenant_method = :current_tenant_id
      @tenant_model = nil
      @redis_enabled = true
      @redis_namespace = "content_signals"
      @maxmind_db_path = default_maxmind_path
      @track_bots = false
      @track_admins = false
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
