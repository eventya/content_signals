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
end
