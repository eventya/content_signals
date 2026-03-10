# frozen_string_literal: true

module ContentSignals
  module Geoip
    # No-op provider — disables geolocation entirely.
    # Use when you don't want any IP lookup performed.
    class NullProvider < BaseProvider
      def self.locate(_ip_address)
        nil
      end
    end
  end
end
