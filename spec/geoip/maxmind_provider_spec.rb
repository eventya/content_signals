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

    context "when MaxMindDB raises an error" do
      let(:fake_error_class) { Class.new(StandardError) }

      before do
        ContentSignals.configure { |c| c.maxmind_db_path = "/fake/path.mmdb" }
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with("/fake/path.mmdb").and_return(true)

        fake_db = double("MaxMindDB")
        stub_const("MaxMindDB", Module.new)
        stub_const("MaxMindDB::Error", fake_error_class)
        allow(MaxMindDB).to receive(:new).and_return(fake_db)
        allow(fake_db).to receive(:lookup).and_raise(MaxMindDB::Error, "invalid database")
      end

      it "returns nil and logs the error" do
        expect(Rails.logger).to receive(:error).with(/MaxMind lookup error/)
        expect(described_class.locate("8.8.8.8")).to be_nil
      end
    end
  end

  describe ".reset!" do
    it "clears the cached DB handle" do
      # Ensure reset! doesn't raise and is callable
      expect { described_class.reset! }.not_to raise_error
    end
  end
end
