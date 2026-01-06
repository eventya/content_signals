# frozen_string_literal: true

require "spec_helper"

RSpec.describe ContentSignals do
  it "has a version number" do
    expect(ContentSignals::VERSION).not_to be nil
  end

  describe ".configure" do
    it "yields configuration" do
      ContentSignals.configure do |config|
        expect(config).to be_a(ContentSignals::Configuration)
      end
    end

    it "allows setting configuration options" do
      ContentSignals.configure do |config|
        config.multitenancy = true
        config.track_bots = true
      end

      expect(ContentSignals.configuration.multitenancy).to be true
      expect(ContentSignals.configuration.track_bots).to be true
    end
  end

  describe ".reset_configuration!" do
    it "resets to default configuration" do
      ContentSignals.configure do |config|
        config.multitenancy = true
      end

      ContentSignals.reset_configuration!

      expect(ContentSignals.configuration.multitenancy).to be false
    end
  end
end
