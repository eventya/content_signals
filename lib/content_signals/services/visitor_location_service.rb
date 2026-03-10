# frozen_string_literal: true

module ContentSignals
  # Thin dispatcher: delegates IP geolocation to the configured provider.
  # Switch providers via ContentSignals.configure { |c| c.geoip_provider = :ipinfo }
  class VisitorLocationService
    def self.locate(ip_address)
      ContentSignals.configuration.resolved_geoip_provider.locate(ip_address)
    end

    # Convenience: is this a local/private IP?
    def self.local_ip?(ip)
      Geoip::BaseProvider.local_ip?(ip)
    end
  end
end
