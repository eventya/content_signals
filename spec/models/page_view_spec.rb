# frozen_string_literal: true

require "rails_helper"

RSpec.describe ContentSignals::PageView do
  let(:page) { Page.create!(title: "Test Page") }
  let(:user) { User.create!(email: "test@example.com") }

  describe "associations" do
    it { expect(subject).to respond_to(:trackable) }
    it { expect(subject).to respond_to(:user) }

    it "belongs to trackable polymorphically" do
      page_view = described_class.create!(
        trackable: page,
        visitor_id: "visitor123",
        viewed_at: Time.current
      )

      expect(page_view.trackable).to eq(page)
      expect(page_view.trackable_type).to eq("Page")
    end

    it "increments counter cache on trackable" do
      expect {
        described_class.create!(
          trackable: page,
          visitor_id: "visitor123",
          viewed_at: Time.current
        )
      }.to change { page.reload.page_views_count }.by(1)
    end
  end

  describe "validations" do
    it "requires trackable_type" do
      page_view = described_class.new(trackable_id: 1, visitor_id: "test", viewed_at: Time.current)
      expect(page_view).not_to be_valid
      expect(page_view.errors[:trackable_type]).to include("can't be blank")
    end

    it "requires visitor_id" do
      page_view = described_class.new(trackable: page, viewed_at: Time.current)
      expect(page_view).not_to be_valid
      expect(page_view.errors[:visitor_id]).to include("can't be blank")
    end

    it "requires viewed_at" do
      page_view = described_class.new(trackable: page, visitor_id: "test")
      expect(page_view).not_to be_valid
      expect(page_view.errors[:viewed_at]).to include("can't be blank")
    end

    it "validates country_code length" do
      page_view = described_class.new(
        trackable: page,
        visitor_id: "test",
        viewed_at: Time.current,
        country_code: "USA"
      )
      expect(page_view).not_to be_valid
    end

    it "validates device_type inclusion" do
      page_view = described_class.new(
        trackable: page,
        visitor_id: "test",
        viewed_at: Time.current,
        device_type: "invalid"
      )
      expect(page_view).not_to be_valid
    end

    it "validates app_platform inclusion" do
      page_view = described_class.new(
        trackable: page,
        visitor_id: "test",
        viewed_at: Time.current,
        app_platform: "invalid"
      )
      expect(page_view).not_to be_valid
    end
  end

  describe "time period scopes" do
    before do
      # Create views at different times
      described_class.create!(trackable: page, visitor_id: "v1", viewed_at: 2.days.ago)
      described_class.create!(trackable: page, visitor_id: "v2", viewed_at: 1.day.ago)
      described_class.create!(trackable: page, visitor_id: "v3", viewed_at: 2.hours.ago)
      described_class.create!(trackable: page, visitor_id: "v4", viewed_at: 8.days.ago)
      described_class.create!(trackable: page, visitor_id: "v5", viewed_at: 35.days.ago)
    end

    it ".today returns today's views" do
      expect(described_class.today.count).to eq(1)
    end

    it ".yesterday returns yesterday's views" do
      expect(described_class.yesterday.count).to eq(1)
    end

    it ".last_30_days returns views from last 30 days" do
      expect(described_class.last_30_days.count).to eq(4)
    end

    it ".last_90_days returns views from last 90 days" do
      expect(described_class.last_90_days.count).to eq(5)
    end
  end

  describe "device scopes" do
    before do
      described_class.create!(trackable: page, visitor_id: "v1", viewed_at: Time.current, device_type: "mobile")
      described_class.create!(trackable: page, visitor_id: "v2", viewed_at: Time.current, device_type: "desktop")
      described_class.create!(trackable: page, visitor_id: "v3", viewed_at: Time.current, device_type: "tablet")
    end

    it ".mobile returns mobile views" do
      expect(described_class.mobile.count).to eq(1)
    end

    it ".desktop returns desktop views" do
      expect(described_class.desktop.count).to eq(1)
    end

    it ".tablet returns tablet views" do
      expect(described_class.tablet.count).to eq(1)
    end
  end

  describe "platform scopes" do
    before do
      described_class.create!(trackable: page, visitor_id: "v1", viewed_at: Time.current, app_platform: "native")
      described_class.create!(trackable: page, visitor_id: "v2", viewed_at: Time.current, app_platform: "hybrid")
      described_class.create!(trackable: page, visitor_id: "v3", viewed_at: Time.current, app_platform: nil)
    end

    it ".from_hybrid_app returns web_view platform views" do
      expect(described_class.from_hybrid_app.count).to eq(1)
    end

    it ".from_native_app returns all app platform views" do
      expect(described_class.from_native_app.count).to eq(1)
    end

    it ".from_website returns web browser views" do
      expect(described_class.from_website.count).to eq(1)
    end
  end

  describe "location scopes" do
    before do
      described_class.create!(
        trackable: page,
        visitor_id: "v1",
        viewed_at: Time.current,
        country_code: "US",
        country_name: "United States",
        city: "New York"
      )
      described_class.create!(
        trackable: page,
        visitor_id: "v2",
        viewed_at: Time.current,
        country_code: "RO",
        country_name: "Romania",
        city: "Bucharest"
      )
    end

    it ".from_country filters by country code" do
      expect(described_class.from_country("US").count).to eq(1)
      expect(described_class.from_country("ro").count).to eq(1) # case insensitive
    end

    it ".from_city filters by city" do
      expect(described_class.from_city("New York").count).to eq(1)
    end
  end

  describe "user scopes" do
    before do
      described_class.create!(trackable: page, visitor_id: "v1", viewed_at: Time.current, user: user)
      described_class.create!(trackable: page, visitor_id: "v2", viewed_at: Time.current, user: nil)
    end

    it ".authenticated returns views with user" do
      expect(described_class.authenticated.count).to eq(1)
    end

    it ".anonymous returns views without user" do
      expect(described_class.anonymous.count).to eq(1)
    end
  end

  describe ".unique_count" do
    before do
      # Same visitor, different times
      described_class.create!(trackable: page, visitor_id: "v1", viewed_at: 1.hour.ago)
      described_class.create!(trackable: page, visitor_id: "v1", viewed_at: 2.hours.ago)
      # Different visitor
      described_class.create!(trackable: page, visitor_id: "v2", viewed_at: 3.hours.ago)
    end

    it "counts unique visitors" do
      expect(described_class.unique_count).to eq(2)
    end

    it "accepts time period parameter" do
      expect(described_class.unique_count(:today)).to eq(2)
    end
  end

  describe ".top_countries" do
    before do
      3.times { described_class.create!(trackable: page, visitor_id: "v#{rand(1000)}", viewed_at: Time.current, country_code: "US", country_name: "United States") }
      2.times { described_class.create!(trackable: page, visitor_id: "v#{rand(1000)}", viewed_at: Time.current, country_code: "RO", country_name: "Romania") }
      1.times { described_class.create!(trackable: page, visitor_id: "v#{rand(1000)}", viewed_at: Time.current, country_code: "UK", country_name: "United Kingdom") }
    end

    it "returns top countries by view count" do
      result = described_class.top_countries(2)
      expect(result.keys.first).to eq(["US", "United States"])
      expect(result.values.first).to eq(3)
    end
  end

  describe ".top_cities" do
    before do
      2.times { described_class.create!(trackable: page, visitor_id: "v#{rand(1000)}", viewed_at: Time.current, city: "New York", country_name: "United States") }
      1.times { described_class.create!(trackable: page, visitor_id: "v#{rand(1000)}", viewed_at: Time.current, city: "Bucharest", country_name: "Romania") }
    end

    it "returns top cities by view count" do
      result = described_class.top_cities
      expect(result.keys.first).to eq(["New York", "United States"])
      expect(result.values.first).to eq(2)
    end
  end

  describe ".device_breakdown" do
    before do
      described_class.create!(trackable: page, visitor_id: "v1", viewed_at: Time.current, device_type: "mobile")
      described_class.create!(trackable: page, visitor_id: "v2", viewed_at: Time.current, device_type: "mobile")
      described_class.create!(trackable: page, visitor_id: "v3", viewed_at: Time.current, device_type: "desktop")
    end

    it "returns device breakdown" do
      result = described_class.device_breakdown
      expect(result["mobile"]).to eq(2)
      expect(result["desktop"]).to eq(1)
    end
  end

  describe ".browser_breakdown" do
    before do
      described_class.create!(trackable: page, visitor_id: "v1", viewed_at: Time.current, browser: "Chrome")
      described_class.create!(trackable: page, visitor_id: "v2", viewed_at: Time.current, browser: "Chrome")
      described_class.create!(trackable: page, visitor_id: "v3", viewed_at: Time.current, browser: "Safari")
    end

    it "returns browser breakdown" do
      result = described_class.browser_breakdown
      expect(result["Chrome"]).to eq(2)
      expect(result["Safari"]).to eq(1)
    end
  end

  describe ".location_heatmap" do
    before do
      described_class.create!(
        trackable: page,
        visitor_id: "v1",
        viewed_at: Time.current,
        latitude: 40.7128,
        longitude: -74.0060
      )
      described_class.create!(
        trackable: page,
        visitor_id: "v2",
        viewed_at: Time.current,
        latitude: 40.7128,
        longitude: -74.0060
      )
    end

    it "returns location data for map visualization" do
      result = described_class.location_heatmap
      expect(result).to be_an(Array)
      expect(result.first).to include(lat: 40.7128, lng: -74.006, count: 2)
    end
  end

  describe ".growth_rate" do
    it "calculates growth rate for period" do
      # Last 30 days: 2 views
      described_class.create!(trackable: page, visitor_id: "v1", viewed_at: 10.days.ago)
      described_class.create!(trackable: page, visitor_id: "v2", viewed_at: 15.days.ago)

      # Previous 30 days: 1 view
      described_class.create!(trackable: page, visitor_id: "v3", viewed_at: 45.days.ago)

      rate = described_class.growth_rate(:last_30_days)
      expect(rate).to eq(100.0) # 100% growth
    end
  end

  describe "instance methods" do
    let(:web_view) do
      described_class.create!(
        trackable: page,
        visitor_id: "v1",
        viewed_at: Time.current,
        device_type: "desktop",
        app_platform: nil
      )
    end

    let(:app_view) do
      described_class.create!(
        trackable: page,
        visitor_id: "v2",
        viewed_at: Time.current,
        device_type: "tablet",
        app_platform: "hybrid"
      )
    end

    let(:mobile_view) do
      described_class.create!(
        trackable: page,
        visitor_id: "v3",
        viewed_at: Time.current,
        device_type: "mobile",
        app_platform: "native"
      )
    end

    let(:authenticated_view) do
      described_class.create!(
        trackable: page,
        visitor_id: "v4",
        viewed_at: Time.current,
        user: user
      )
    end

    describe "#web_browser?" do
      it "returns true for web views" do
        expect(web_view.web_browser?).to be true
      end

      it "returns false for app views" do
        expect(app_view.web_browser?).to be false
      end
    end

    describe "#hybrid_app?" do
      it "returns true for app views" do
        expect(app_view.hybrid_app?).to be true
      end

      it "returns false for web views" do
        expect(web_view.hybrid_app?).to be false
      end
    end

    describe "#mobile_device?" do
      it "returns true for mobile" do
        expect(mobile_view.mobile_device?).to be true
      end

      it "returns false for desktop" do
        expect(web_view.mobile_device?).to be false
      end
    end

    describe "#desktop_device?" do
      it "returns true for desktop" do
        expect(web_view.desktop_device?).to be true
      end

      it "returns false for mobile" do
        expect(mobile_view.desktop_device?).to be false
      end
    end

    describe "#authenticated?" do
      it "returns true when user is present" do
        expect(authenticated_view.authenticated?).to be true
      end

      it "returns false when user is nil" do
        expect(web_view.authenticated?).to be false
      end
    end

    describe "#anonymous?" do
      it "returns true when user is nil" do
        expect(web_view.anonymous?).to be true
      end

      it "returns false when user is present" do
        expect(authenticated_view.anonymous?).to be false
      end
    end
  end
end
