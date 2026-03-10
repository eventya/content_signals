# frozen_string_literal: true

module ContentSignals
  # Downloads/refreshes the MaxMind GeoLite2-City database from the public mirror.
  # Only runs when geoip_provider is :maxmind and maxmind_db_path is configured.
  # Schedule via config/recurring.yml (added by `rails generate content_signals:install`).
  class UpdateGeoipDatabaseJob < ActiveJob::Base
    queue_as :default

    MIRROR_URL = "https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-City.mmdb"

    def perform
      config = ContentSignals.configuration

      unless config.geoip_provider == :maxmind
        Rails.logger.info "[ContentSignals] UpdateGeoipDatabaseJob skipped: geoip_provider is not :maxmind"
        return
      end

      db_path = config.maxmind_db_path
      unless db_path.present?
        Rails.logger.warn "[ContentSignals] UpdateGeoipDatabaseJob skipped: maxmind_db_path not configured"
        return
      end

      download(db_path.to_s)
    end

    private

    def download(db_path)
      require "open-uri"
      require "fileutils"

      FileUtils.mkdir_p(File.dirname(db_path))

      tmp_path = "#{db_path}.tmp"

      Rails.logger.info "[ContentSignals] Downloading GeoLite2-City from mirror..."

      URI.open(MIRROR_URL, "rb",  # rubocop:disable Security/Open
               "User-Agent" => "Mozilla/5.0",
               read_timeout: 120,
               open_timeout: 15) do |remote|
        File.binwrite(tmp_path, remote.read)
      end

      File.rename(tmp_path, db_path)

      size_mb = (File.size(db_path) / 1_048_576.0).round(1)
      Rails.logger.info "[ContentSignals] GeoLite2-City updated: #{db_path} (#{size_mb} MB)"

      # Bust the cached DB handle so next lookup uses the fresh file
      ContentSignals::Geoip::MaxmindProvider.reset!
    rescue => e
      File.delete(tmp_path) if tmp_path && File.exist?(tmp_path)
      Rails.logger.error "[ContentSignals] GeoLite2 update failed: #{e.message}"
      raise
    end
  end
end
