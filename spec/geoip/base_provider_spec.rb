# frozen_string_literal: true

require "rails_helper"

RSpec.describe ContentSignals::Geoip::BaseProvider do
  describe ".local_ip?" do
    it "returns true for nil" do
      expect(described_class.local_ip?(nil)).to be true
    end

    it "returns true for localhost string" do
      expect(described_class.local_ip?("localhost")).to be true
    end

    it "returns true for ::1 (IPv6 loopback)" do
      expect(described_class.local_ip?("::1")).to be true
    end

    it "returns true for 127.x.x.x" do
      expect(described_class.local_ip?("127.0.0.1")).to be true
      expect(described_class.local_ip?("127.0.0.5")).to be true
    end

    it "returns true for 192.168.x.x" do
      expect(described_class.local_ip?("192.168.1.1")).to be true
      expect(described_class.local_ip?("192.168.0.100")).to be true
    end

    it "returns true for 10.x.x.x" do
      expect(described_class.local_ip?("10.0.0.1")).to be true
    end

    it "returns true for 172.x.x.x" do
      expect(described_class.local_ip?("172.16.0.1")).to be true
    end

    it "returns true for IPv6 ULA (fc00:)" do
      expect(described_class.local_ip?("fc00::1")).to be true
    end

    it "returns true for IPv6 link-local (fe80:)" do
      expect(described_class.local_ip?("fe80::1")).to be true
    end

    it "returns false for public IPv4" do
      expect(described_class.local_ip?("93.123.15.10")).to be false
      expect(described_class.local_ip?("8.8.8.8")).to be false
    end

    it "returns false for public IPv6" do
      expect(described_class.local_ip?("2001:db8::1")).to be false
    end
  end

  describe ".locate" do
    it "raises NotImplementedError" do
      expect { described_class.locate("1.2.3.4") }.to raise_error(NotImplementedError)
    end
  end
end
