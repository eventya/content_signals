# frozen_string_literal: true

module ContentSignals
  module Geoip
    # Offline geolocation using a local MaxMind GeoLite2-City .mmdb file.
    # Requires the maxminddb gem.
    # Download/update the database: bundle exec rake stejar:geoip:update
    class MaxmindProvider < BaseProvider
      def self.locate(ip_address)
        return nil if ip_address.blank? || local_ip?(ip_address)

        db_path = ContentSignals.configuration.maxmind_db_path
        return nil unless db_path && File.exist?(db_path.to_s)

        db = @db ||= MaxMindDB.new(db_path.to_s)
        result = db.lookup(ip_address)
        return nil unless result&.found?

        {
          country_code: result.country.iso_code,
          country_name: result.country.name,
          city:         result.city.name,
          region:       result.subdivisions.most_specific&.name,
          latitude:     result.location.latitude,
          longitude:    result.location.longitude
        }
      rescue MaxMindDB::Error => e
        Rails.logger.error "MaxMind lookup error: #{e.message}"
        nil
      rescue => e
        Rails.logger.error "MaxMind geolocation error: #{e.message}"
        nil
      end

      # Reset cached DB handle (useful after db file is updated)
      def self.reset!
        @db = nil
      end
    end
  end
end
