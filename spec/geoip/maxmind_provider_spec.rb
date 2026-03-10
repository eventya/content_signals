# frozen_string_literal: true

require "rails_helper"

RSpec.describe ContentSignals::Geoip::MaxmindProvider do
  before { described_class.reset! }

  describe ".locate" do
    context "with local/private IP" do
      it "returns nil for loopback" do
        expect(described_class.locate("127.0.0.1")).to be_nil
      end

      it "returns nil for private network" do
        expect(described_class.locate("192.168.1.1")).to be_nil
      end

      it "returns nil for nil ip" do
        expect(described_class.locate(nil)).to be_nil
      end

      it "returns nil for blank ip" do
        expect(described_class.locate("")).to be_nil
      end
    end

    context "when maxmind_db_path is not configured" do
      before do
        ContentSignals.configure { |c| c.maxmind_db_path = nil }
      end

      it "returns nil" do
        expect(described_class.locate("93.123.15.10")).to be_nil
      end
    end

    context "when database file does not exist" do
      before do
        ContentSignals.configure { |c| c.maxmind_db_path = "/nonexistent/path/GeoLite2-City.mmdb" }
      end

      it "returns nil" do
        expect(described_class.locate("93.123.15.10")).to be_nil
      end
    end

    context "with a real database file", :requires_mmdb do
      let(:db_path) { Rails.root.join("db", "GeoLite2-City.mmdb") }

      before do
        skip "GeoLite2-City.mmdb not present" unless File.exist?(db_path.to_s)
        ContentSignals.configure { |c| c.maxmind_db_path = db_path }
      end

      it "returns location data for a public IP" do
        result = described_class.locate("8.8.8.8")

        expect(result).to be_a(Hash)
        expect(result).to include(:country_code, :country_name, :city, :region, :latitude, :longitude)
        expect(result[:country_code]).to be_a(String)
      end
    end

    context "when address is not found in database" do
      before do
        ContentSignals.configure { |c| c.maxmind_db_path = "/fake/path.mmdb" }
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with("/fake/path.mmdb").and_return(true)

        fake_reader = double("MaxMind::GeoIP2::Reader")
        fake_reader_class = double("MaxMind::GeoIP2::Reader class")
        allow(fake_reader_class).to receive(:new).and_return(fake_reader)

        not_found_error = Class.new(StandardError)
        stub_const("MaxMind::GeoIP2::Reader", fake_reader_class)
        stub_const("MaxMind::GeoIP2::AddressNotFoundError", not_found_error)

        allow(fake_reader).to receive(:city).and_raise(MaxMind::GeoIP2::AddressNotFoundError)
      end

      it "returns nil without logging" do
        expect(Rails.logger).not_to receive(:error)
        expect(described_class.locate("8.8.8.8")).to be_nil
      end
    end

    context "when reader raises an unexpected error" do
      before do
        ContentSignals.configure { |c| c.maxmind_db_path = "/fake/path.mmdb" }
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with("/fake/path.mmdb").and_return(true)

        fake_reader = double("MaxMind::GeoIP2::Reader")
        fake_reader_class = double("MaxMind::GeoIP2::Reader class")
        allow(fake_reader_class).to receive(:new).and_return(fake_reader)

        stub_const("MaxMind::GeoIP2::Reader", fake_reader_class)
        stub_const("MaxMind::GeoIP2::AddressNotFoundError", Class.new(StandardError))

        allow(fake_reader).to receive(:city).and_raise(RuntimeError, "corrupt database")
      end

      it "returns nil and logs the error" do
        expect(Rails.logger).to receive(:error).with(/MaxMind geolocation error/)
        expect(described_class.locate("8.8.8.8")).to be_nil
      end
    end
  end

  describe ".reset!" do
    it "clears the cached reader handle" do
      expect { described_class.reset! }.not_to raise_error
    end
  end
end
