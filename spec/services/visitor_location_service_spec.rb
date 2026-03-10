# frozen_string_literal: true

require "rails_helper"

RSpec.describe ContentSignals::VisitorLocationService do
  describe ".locate" do
    it "delegates to the configured provider" do
      allow(ContentSignals::Geoip::MaxmindProvider).to receive(:locate).with("8.8.8.8").and_return(
        country_code: "US", country_name: "United States", city: "Mountain View",
        region: "California", latitude: 37.4056, longitude: -122.0775
      )

      result = described_class.locate("8.8.8.8")

      expect(ContentSignals::Geoip::MaxmindProvider).to have_received(:locate).with("8.8.8.8")
      expect(result[:country_code]).to eq("US")
    end

    context "when provider is :maxmind" do
      before { ContentSignals.configure { |c| c.geoip_provider = :maxmind } }

      it "uses MaxmindProvider" do
        allow(ContentSignals::Geoip::MaxmindProvider).to receive(:locate).and_return(nil)
        described_class.locate("1.2.3.4")
        expect(ContentSignals::Geoip::MaxmindProvider).to have_received(:locate)
      end
    end

    context "when provider is :ipinfo" do
      before { ContentSignals.configure { |c| c.geoip_provider = :ipinfo } }

      it "uses IpinfoProvider" do
        allow(ContentSignals::Geoip::IpinfoProvider).to receive(:locate).and_return(nil)
        described_class.locate("1.2.3.4")
        expect(ContentSignals::Geoip::IpinfoProvider).to have_received(:locate)
      end
    end

    context "when provider is :null" do
      before { ContentSignals.configure { |c| c.geoip_provider = :null } }

      it "always returns nil" do
        expect(described_class.locate("8.8.8.8")).to be_nil
      end
    end

    context "with a custom provider class" do
      let(:custom_provider) do
        Class.new do
          def self.locate(_ip)
            { country_code: "XY", country_name: "Custom Land", city: nil,
              region: nil, latitude: nil, longitude: nil }
          end
        end
      end

      before { ContentSignals.configure { |c| c.geoip_provider = custom_provider } }

      it "delegates to the custom class" do
        result = described_class.locate("1.2.3.4")
        expect(result[:country_code]).to eq("XY")
      end
    end
  end

  describe ".local_ip?" do
    it "delegates to BaseProvider" do
      expect(described_class.local_ip?("127.0.0.1")).to be true
      expect(described_class.local_ip?("8.8.8.8")).to be false
    end
  end
end
