# frozen_string_literal: true

require "rails_helper"

RSpec.describe ContentSignals::Geoip::IpinfoProvider do
  describe ".locate" do
    context "with local/private IP" do
      it "returns nil for loopback" do
        expect(described_class.locate("127.0.0.1")).to be_nil
      end

      it "returns nil for nil ip" do
        expect(described_class.locate(nil)).to be_nil
      end

      it "returns nil for blank ip" do
        expect(described_class.locate("")).to be_nil
      end
    end

    context "when no token is configured" do
      before do
        ContentSignals.configure { |c| c.geoip_token = nil }
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("IPINFO_TOKEN").and_return(nil)
      end

      it "returns nil without making any HTTP request" do
        expect(Net::HTTP).not_to receive(:get_response)
        expect(described_class.locate("93.123.15.10")).to be_nil
      end
    end

    context "with a configured token" do
      let(:token) { "test_token_123" }
      let(:ip) { "93.123.15.10" }

      let(:api_response) do
        {
          "ip"       => ip,
          "city"     => "Bucharest",
          "region"   => "Bucharest",
          "country"  => "RO",
          "loc"      => "44.4268,26.1025",
          "org"      => "AS8708 RCS & RDS SA"
        }.to_json
      end

      before do
        ContentSignals.configure { |c| c.geoip_token = token }

        fake_response = instance_double(Net::HTTPResponse, body: api_response)
        allow(described_class).to receive(:fetch).with(ip, token).and_return(JSON.parse(api_response))
      end

      it "returns a location hash" do
        result = described_class.locate(ip)

        expect(result).to include(
          country_code: "RO",
          city:         "Bucharest",
          region:       "Bucharest",
          latitude:     44.4268,
          longitude:    26.1025
        )
      end

      it "includes country_code" do
        result = described_class.locate(ip)
        expect(result[:country_code]).to eq("RO")
      end
    end

    context "when API returns no country" do
      before do
        ContentSignals.configure { |c| c.geoip_token = "token" }
        allow(described_class).to receive(:fetch).and_return({ "ip" => "1.2.3.4" })
      end

      it "returns nil" do
        expect(described_class.locate("1.2.3.4")).to be_nil
      end
    end

    context "when API call raises an error" do
      before do
        ContentSignals.configure { |c| c.geoip_token = "token" }
        allow(described_class).to receive(:fetch).and_raise(StandardError, "connection refused")
      end

      it "returns nil and logs the error" do
        expect(Rails.logger).to receive(:error).with(/IPinfo geolocation error/)
        expect(described_class.locate("8.8.8.8")).to be_nil
      end
    end

    context "when loc field is missing" do
      before do
        ContentSignals.configure { |c| c.geoip_token = "token" }
        allow(described_class).to receive(:fetch).and_return(
          { "ip" => "1.2.3.4", "country" => "US", "city" => "New York" }
        )
      end

      it "returns nil for latitude and longitude" do
        result = described_class.locate("1.2.3.4")
        expect(result[:latitude]).to be_nil
        expect(result[:longitude]).to be_nil
        expect(result[:country_code]).to eq("US")
      end
    end
  end
end
