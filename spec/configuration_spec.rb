# frozen_string_literal: true

require "rails_helper"

RSpec.describe ContentSignals::Configuration do
  describe "#initialize" do
    it "sets default values" do
      config = ContentSignals::Configuration.new

      expect(config.multitenancy).to be false
      expect(config.current_tenant_method).to eq(:current_tenant_id)
      expect(config.redis_enabled).to be true
      expect(config.track_bots).to be false
      expect(config.track_admins).to be false
    end
  end

  describe "#multitenancy?" do
    it "returns multitenancy setting" do
      config = ContentSignals::Configuration.new
      expect(config.multitenancy?).to be false

      config.multitenancy = true
      expect(config.multitenancy?).to be true
    end
  end

  describe "#redis_enabled?" do
    it "checks if redis is enabled and available" do
      config = ContentSignals::Configuration.new
      config.redis_enabled = false

      # When disabled, should return false
      expect(config.redis_enabled?).to be false
    end
  end

  describe "#resolved_geoip_provider" do
    it "defaults to MaxmindProvider" do
      config = ContentSignals::Configuration.new
      expect(config.resolved_geoip_provider).to eq(ContentSignals::Geoip::MaxmindProvider)
    end

    it "resolves :maxmind to MaxmindProvider" do
      config = ContentSignals::Configuration.new
      config.geoip_provider = :maxmind
      expect(config.resolved_geoip_provider).to eq(ContentSignals::Geoip::MaxmindProvider)
    end

    it "resolves :ipinfo to IpinfoProvider" do
      config = ContentSignals::Configuration.new
      config.geoip_provider = :ipinfo
      expect(config.resolved_geoip_provider).to eq(ContentSignals::Geoip::IpinfoProvider)
    end

    it "resolves :null to NullProvider" do
      config = ContentSignals::Configuration.new
      config.geoip_provider = :null
      expect(config.resolved_geoip_provider).to eq(ContentSignals::Geoip::NullProvider)
    end

    it "returns a custom class directly" do
      custom = Class.new { def self.locate(_ip) = nil }
      config = ContentSignals::Configuration.new
      config.geoip_provider = custom
      expect(config.resolved_geoip_provider).to eq(custom)
    end

    it "raises ArgumentError for unknown symbol" do
      config = ContentSignals::Configuration.new
      config.geoip_provider = :unknown_provider
      expect { config.resolved_geoip_provider }.to raise_error(ArgumentError, /Unknown geoip_provider/)
    end
  end

  describe "geoip_token" do
    it "defaults to nil" do
      config = ContentSignals::Configuration.new
      expect(config.geoip_token).to be_nil
    end

    it "can be set" do
      config = ContentSignals::Configuration.new
      config.geoip_token = "my_token"
      expect(config.geoip_token).to eq("my_token")
    end
  end
end
