# frozen_string_literal: true

module ContentSignals
  module Geoip
    # Offline geolocation using a local MaxMind GeoLite2-City .mmdb file.
    # Requires the maxmind-geoip2 gem.
    # Download/update the database: bundle exec rake stejar:geoip:update
    class MaxmindProvider < BaseProvider
      def self.locate(ip_address)
        return nil if ip_address.blank? || local_ip?(ip_address)

        db_path = ContentSignals.configuration.maxmind_db_path
        return nil unless db_path && File.exist?(db_path.to_s)

        reader = @reader ||= MaxMind::GeoIP2::Reader.new(database: db_path.to_s)
        record = reader.city(ip_address)

        {
          country_code: record.country.iso_code,
          country_name: record.country.name,
          city:         record.city.name,
          region:       record.subdivisions.most_specific&.name,
          latitude:     record.location.latitude,
          longitude:    record.location.longitude
        }
      rescue MaxMind::GeoIP2::AddressNotFoundError
        nil
      rescue => e
        Rails.logger.error "MaxMind geolocation error: #{e.message}"
        nil
      end

      # Reset cached reader handle (call after db file is updated)
      def self.reset!
        @reader = nil
      end
    end
  end
end
