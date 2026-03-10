# frozen_string_literal: true

module ContentSignals
  module Geoip
    # Online geolocation via IPinfo.io API.
    # Requires: IPINFO_TOKEN env var (or config.geoip_token)
    # Requires the http gem (gem "http") or net/http (built-in, used as fallback).
    class IpinfoProvider < BaseProvider
      API_BASE = "https://ipinfo.io"

      def self.locate(ip_address)
        return nil if ip_address.blank? || local_ip?(ip_address)

        token = ContentSignals.configuration.geoip_token || ENV["IPINFO_TOKEN"]
        return nil unless token.present?

        data = fetch(ip_address, token)
        return nil unless data && data["country"]

        lat, lng = data["loc"]&.split(",")&.map(&:to_f)

        {
          country_code: data["country"],
          country_name: country_name(data["country"]),
          city:         data["city"],
          region:       data["region"],
          latitude:     lat,
          longitude:    lng
        }
      rescue => e
        Rails.logger.error "IPinfo geolocation error: #{e.message}"
        nil
      end

      def self.fetch(ip, token)
        uri = URI("#{API_BASE}/#{ip}/json?token=#{token}")
        response = Net::HTTP.get_response(uri)
        JSON.parse(response.body)
      end

      def self.country_name(code)
        return nil unless defined?(ISO3166)

        ISO3166::Country[code]&.name
      rescue
        nil
      end
    end
  end
end
