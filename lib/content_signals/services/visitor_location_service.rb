# frozen_string_literal: true

module ContentSignals
  class VisitorLocationService
    def self.locate(ip_address)
      return nil if ip_address.blank? || local_ip?(ip_address)

      db_path = ContentSignals.configuration.maxmind_db_path
      return nil unless db_path && File.exist?(db_path)

      # Initialize database connection (cached in production)
      db = @db ||= MaxMindDB.new(db_path.to_s)
      result = db.lookup(ip_address)

      return nil unless result&.found?

      {
        country_code: result.country.iso_code,
        country_name: result.country.name,
        city: result.city.name,
        region: result.subdivisions.most_specific&.name,
        latitude: result.location.latitude,
        longitude: result.location.longitude
      }
    rescue MaxMindDB::Error => e
      Rails.logger.error "MaxMind lookup error: #{e.message}"
      nil
    rescue => e
      Rails.logger.error "Geolocation error: #{e.message}"
      nil
    end

    def self.local_ip?(ip)
      return true if ip.nil?

      ip_str = ip.to_s
      ip_str.start_with?('127.', '192.168.', '10.', '172.', 'fc00:', 'fe80:') ||
      ip_str == '::1' ||
      ip_str == 'localhost'
    end

    # Fallback to API if database not available (optional)
    def self.locate_via_api(ip_address)
      return nil if ip_address.blank? || local_ip?(ip_address)
      return nil unless defined?(HTTP)

      token = ENV['IPINFO_TOKEN']
      return nil unless token

      # Using IPinfo.io as fallback
      response = HTTP.get("https://ipinfo.io/#{ip_address}/json", params: { token: token })
      data = JSON.parse(response.body)

      return nil unless data['country']

      lat, lng = data['loc']&.split(',')&.map(&:to_f)

      {
        country_code: data['country'],
        country_name: country_name_from_code(data['country']),
        city: data['city'],
        region: data['region'],
        latitude: lat,
        longitude: lng
      }
    rescue => e
      Rails.logger.error "API geolocation error: #{e.message}"
      nil
    end

    def self.country_name_from_code(code)
      return nil unless defined?(ISO3166)

      country = ISO3166::Country[code]
      country&.name
    rescue
      nil
    end
  end
end
