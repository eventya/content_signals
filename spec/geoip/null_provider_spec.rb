# frozen_string_literal: true

require "rails_helper"

RSpec.describe ContentSignals::Geoip::NullProvider do
  describe ".locate" do
    it "always returns nil for any IP" do
      expect(described_class.locate("8.8.8.8")).to be_nil
    end

    it "returns nil for local IP" do
      expect(described_class.locate("127.0.0.1")).to be_nil
    end

    it "returns nil for nil input" do
      expect(described_class.locate(nil)).to be_nil
    end
  end
end
