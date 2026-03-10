# frozen_string_literal: true

module ContentSignals
  module Geoip
    # Base interface for IP geolocation providers.
    # All providers must implement `.locate(ip_address)` and return either:
    #   - A Hash with keys: :country_code, :country_name, :city, :region, :latitude, :longitude
    #   - nil  (when IP is local, lookup fails, or provider is disabled)
    class BaseProvider
      LOCAL_IP_PREFIXES = %w[127. 192.168. 10. 172. fc00: fe80:].freeze
      LOCAL_IP_EXACT    = %w[::1 localhost].freeze

      def self.locate(ip_address)
        raise NotImplementedError, "#{name}.locate must be implemented"
      end

      def self.local_ip?(ip)
        return true if ip.nil?

        ip_str = ip.to_s
        LOCAL_IP_EXACT.include?(ip_str) ||
          LOCAL_IP_PREFIXES.any? { |prefix| ip_str.start_with?(prefix) }
      end
    end
  end
end
