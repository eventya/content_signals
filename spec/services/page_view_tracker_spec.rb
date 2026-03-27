# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContentSignals::PageViewTracker do
  let(:page) { Page.create!(title: 'Test Page', page_views_count: 0) }
  let(:user) { User.create!(email: 'test@example.com') }
  let(:request) do
    MockRequest.new(
      ip: '192.168.1.100',
      user_agent: 'Mozilla/5.0',
      referrer: 'https://google.com'
    )
  end

  describe '.track' do
    it 'creates a new instance and calls track' do
      tracker = instance_double(described_class)
      allow(described_class).to receive(:new).and_return(tracker)
      allow(tracker).to receive(:track)

      described_class.track(trackable: page, request: request, user: user)

      expect(described_class).to have_received(:new).with(page, request, user)
      expect(tracker).to have_received(:track)
    end
  end

  describe '#track' do
    subject(:tracker) { described_class.new(page, request, user) }

    before do
      allow(ContentSignals::DeviceDetectorService).to receive(:detect).and_return(
        device_type: 'desktop',
        browser: 'Chrome',
        os: 'macOS'
      )
    end

    it 'does not immediately increment counter (waits for job execution)' do
      expect { tracker.track }.not_to change { page.reload.page_views_count }
    end

    it 'enqueues a background job' do
      allow(ContentSignals::TrackPageViewJob).to receive(:perform_later)

      tracker.track

      expect(ContentSignals::TrackPageViewJob).to have_received(:perform_later)
    end

    it 'includes visitor_id in tracking data' do
      allow(ContentSignals::TrackPageViewJob).to receive(:perform_later)

      tracker.track

      expect(ContentSignals::TrackPageViewJob).to have_received(:perform_later).with(
        'Page',
        page.id,
        user.id,
        hash_including(visitor_id: "user_#{user.id}")
      )
    end

    it 'includes request metadata in tracking data' do
      allow(ContentSignals::TrackPageViewJob).to receive(:perform_later)

      tracker.track

      expect(ContentSignals::TrackPageViewJob).to have_received(:perform_later).with(
        'Page',
        page.id,
        user.id,
        hash_including(
          ip_address: '192.168.1.100',
          user_agent: 'Mozilla/5.0',
          referrer: 'https://google.com'
        )
      )
    end

    it 'calls device service but NOT location service (location resolved in job)' do
      allow(ContentSignals::VisitorLocationService).to receive(:locate)
      tracker.track

      expect(ContentSignals::VisitorLocationService).not_to have_received(:locate)
      expect(ContentSignals::DeviceDetectorService).to have_received(:detect)
        .with('Mozilla/5.0', app_platform: nil)
    end

    it 'passes ip_address to job for deferred location lookup' do
      allow(ContentSignals::TrackPageViewJob).to receive(:perform_later)

      tracker.track

      expect(ContentSignals::TrackPageViewJob).to have_received(:perform_later).with(
        'Page', page.id, user.id, hash_including(ip_address: '192.168.1.100')
      )
    end

    it 'does not include location fields in job payload (resolved by worker)' do
      allow(ContentSignals::TrackPageViewJob).to receive(:perform_later)

      tracker.track

      expect(ContentSignals::TrackPageViewJob).to have_received(:perform_later).with(
        'Page', page.id, user.id,
        satisfy { |data| !data.key?(:country_code) && !data.key?(:city) }
      )
    end

    context 'when device service returns nil' do
      before do
        allow(ContentSignals::DeviceDetectorService).to receive(:detect).and_return(nil)
      end

      it 'still tracks successfully' do
        expect { tracker.track }.not_to raise_error
      end
    end

    context 'when user revisits the same page multiple times' do
      before do
        allow(ContentSignals::DeviceDetectorService).to receive(:detect).and_return(
          device_type: 'desktop',
          browser: 'Chrome',
          os: 'macOS'
        )
      end

      it 'does not increment counter until jobs execute' do
        expect {
          3.times { tracker.track }
        }.not_to change { page.reload.page_views_count }
      end

      it 'enqueues a job for each visit' do
        allow(ContentSignals::TrackPageViewJob).to receive(:perform_later)

        3.times { tracker.track }

        expect(ContentSignals::TrackPageViewJob).to have_received(:perform_later).exactly(3).times
      end

      it 'uses consistent visitor_id across visits' do
        visitor_ids = []

        allow(ContentSignals::TrackPageViewJob).to receive(:perform_later) do |_type, _id, _user_id, data|
          visitor_ids << data[:visitor_id]
        end

        3.times { tracker.track }

        # All visits should have the same visitor_id
        expect(visitor_ids.uniq.size).to eq(1)
        expect(visitor_ids.first).to eq("user_#{user.id}")
      end

      context 'with Redis enabled' do
        let(:cache_stub) { double('cache') }
        let(:visitor_id) { "user_#{user.id}" }
        let(:cache_key) { "page_view:#{visitor_id}:Page:#{page.id}:#{Date.current}" }

        before do
          stub_const('Rails', Class.new)
          allow(Rails).to receive(:cache).and_return(cache_stub)
          allow(ContentSignals.configuration).to receive(:redis_enabled?).and_return(true)
          allow(cache_stub).to receive(:respond_to?).with(:redis).and_return(true)

          # First call returns false (not seen today), subsequent calls return true
          call_count = 0
          allow(cache_stub).to receive(:exist?) do
            call_count += 1
            call_count > 1
          end

          allow(cache_stub).to receive(:write)
          allow(cache_stub).to receive(:increment)
        end

        it 'only marks first visit as unique for the day' do
          3.times { tracker.track }

          # Cache should only be written once (first visit)
          expect(cache_stub).to have_received(:write).once
        end

        it 'increments unique counter only once per day' do
          3.times { tracker.track }

          # Daily unique counter should only increment once
          expect(cache_stub).to have_received(:increment).with(
            "page_unique_views:Page:#{page.id}:#{Date.current}",
            1
          ).once
        end
      end
    end
  end

  describe '#identify_visitor' do
    subject(:tracker) { described_class.new(page, request, user) }

    context 'with authenticated user' do
      it 'uses user ID for visitor identification' do
        visitor_id = tracker.send(:identify_visitor)
        expect(visitor_id).to eq("user_#{user.id}")
      end
    end

    context 'without user but with device_id header' do
      let(:user) { nil }

      before do
        request.headers['X-Device-ID'] = 'device-abc-123'
      end

      it 'uses device_id for visitor identification' do
        visitor_id = tracker.send(:identify_visitor)
        expect(visitor_id).to eq('device_device-abc-123')
      end
    end

    context 'without user but with device_id param' do
      let(:user) { nil }

      before do
        request.params[:device_id] = 'device-xyz-789'
      end

      it 'uses device_id for visitor identification' do
        visitor_id = tracker.send(:identify_visitor)
        expect(visitor_id).to eq('device_device-xyz-789')
      end
    end

    context 'without user or device_id' do
      let(:user) { nil }

      context 'with existing visitor cookie' do
        before do
          request.cookie_jar.signed[:visitor_id] = 'visitor_existing-cookie-123'
        end

        it 'uses existing cookie value' do
          visitor_id = tracker.send(:identify_visitor)
          expect(visitor_id).to eq('visitor_existing-cookie-123')
        end

        it 'does not set a new cookie' do
          expect(request.cookie_jar).not_to receive(:[]=)
          tracker.send(:identify_visitor)
        end
      end

      context 'without visitor cookie' do
        it 'generates new visitor_id and sets cookie' do
          visitor_id = tracker.send(:identify_visitor)

          expect(visitor_id).to start_with('visitor_')
          expect(visitor_id).to match(/^visitor_[0-9a-f-]{36}$/) # UUID format
        end

        it 'sets signed cookie with proper options' do
          visitor_id = tracker.send(:identify_visitor)

          cookie_data = request.cookie_jar.signed.cookie_data(:visitor_id)
          expect(cookie_data[:value]).to eq(visitor_id)
          expect(cookie_data[:httponly]).to be true
          expect(cookie_data[:same_site]).to eq(:lax)
          expect(cookie_data[:expires]).to be > 1.year.from_now
        end

        it 'returns same visitor_id on subsequent calls without re-setting cookie' do
          visitor_id1 = tracker.send(:identify_visitor)
          visitor_id2 = tracker.send(:identify_visitor)

          expect(visitor_id1).to eq(visitor_id2)
        end
      end

      context 'when cookie_jar is not available' do
        before do
          allow(request).to receive(:respond_to?).with(:cookie_jar).and_return(false)
        end

        it 'falls back to anonymous ID from IP and user agent' do
          visitor_id = tracker.send(:identify_visitor)
          expect(visitor_id).to start_with('anon_')
          expect(visitor_id.length).to eq(21) # "anon_" + 16 chars
        end
      end
    end

    context 'legacy tests for IP-based identification' do
      let(:user) { nil }

      before do
        # Simulate no cookie jar available
        allow(request).to receive(:respond_to?).with(:cookie_jar).and_return(false)
      end

      it 'generates anonymous visitor ID from IP and user agent' do
        tracker = described_class.new(page, request, user)
        visitor_id = tracker.send(:identify_visitor)
        expect(visitor_id).to start_with('anon_')
        expect(visitor_id.length).to eq(21) # "anon_" + 16 chars
      end

      it 'generates consistent ID for same IP and user agent' do
        visitor_id1 = tracker.send(:identify_visitor)
        visitor_id2 = described_class.new(page, request, nil).send(:identify_visitor)
        expect(visitor_id1).to eq(visitor_id2)
      end

      it 'generates different ID for different IP' do
        visitor_id1 = tracker.send(:identify_visitor)

        request2 = MockRequest.new
        request2.ip = '10.0.0.1'
        visitor_id2 = described_class.new(page, request2, nil).send(:identify_visitor)

        expect(visitor_id1).not_to eq(visitor_id2)
      end
    end
  end

  describe '#detect_app_context' do
    subject(:tracker) { described_class.new(page, request, user) }

    context 'with app headers' do
      before do
        request.headers['X-App-Platform'] = 'capacitor'
        request.headers['X-App-Version'] = '1.2.3'
        request.headers['X-Device-ID'] = 'device-123'
      end

      it 'extracts app context from headers' do
        context = tracker.send(:detect_app_context)
        expect(context).to eq(
          app_platform: 'capacitor',
          app_version: '1.2.3',
          device_id: 'device-123'
        )
      end
    end

    context 'without app headers' do
      it 'returns nil values' do
        context = tracker.send(:detect_app_context)
        expect(context[:app_platform]).to be_nil
        expect(context[:app_version]).to be_nil
        expect(context[:device_id]).to be_nil
      end
    end

    context 'with app platform in user agent' do
      before do
        request.user_agent = 'MyApp Capacitor/1.0'
      end

      it 'detects platform from user agent' do
        context = tracker.send(:detect_app_context)
        expect(context[:app_platform]).to eq('capacitor')
      end
    end
  end

  describe '#detect_platform_from_ua' do
    subject(:tracker) { described_class.new(page, request, user) }

    {
      'capacitor' => 'MyApp Capacitor/1.0',
      'cordova' => 'MyApp Cordova/2.0',
      'react_native' => 'MyApp React-Native/3.0',
      'flutter' => 'MyApp Flutter/4.0',
      'webview' => 'Mozilla/5.0 (Linux; Android) WebView'
    }.each do |platform, user_agent|
      it "detects #{platform} from user agent" do
        request.user_agent = user_agent
        result = tracker.send(:detect_platform_from_ua)
        expect(result).to eq(platform)
      end
    end

    it 'detects turbo_native from Turbo Native user agent' do
      request.user_agent = 'Turbo Native iOS/1.0'
      result = tracker.send(:detect_platform_from_ua)
      expect(result).to eq('turbo_native')
    end

    it 'detects turbo_native for Android Turbo Native user agent' do
      request.user_agent = 'Turbo Native Android/1.0'
      result = tracker.send(:detect_platform_from_ua)
      expect(result).to eq('turbo_native')
    end

    it 'returns nil for regular browser user agent' do
      request.user_agent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
      result = tracker.send(:detect_platform_from_ua)
      expect(result).to be_nil
    end
  end

  describe '#detect_locale' do
    subject(:tracker) { described_class.new(page, request, user) }

    it 'extracts locale from Accept-Language header' do
      request.headers['Accept-Language'] = 'en-US,en;q=0.9,ro;q=0.8'
      locale = tracker.send(:detect_locale)
      expect(locale).to eq('en-US')
    end

    it 'handles simple locale' do
      request.headers['Accept-Language'] = 'fr'
      locale = tracker.send(:detect_locale)
      expect(locale).to eq('fr')
    end

    it 'falls back to I18n.locale when header is missing' do
      request.headers.delete('Accept-Language')
      locale = tracker.send(:detect_locale)
      expect(locale).to eq(I18n.locale.to_s)
    end
  end

  describe '#unique_today?' do
    subject(:tracker) { described_class.new(page, request, user) }

    context 'with Redis enabled' do
      let(:cache_stub) { double('cache') }

      before do
        stub_const('Rails', Class.new)
        allow(Rails).to receive(:cache).and_return(cache_stub)
        allow(ContentSignals.configuration).to receive(:redis_enabled?).and_return(true)
        allow(cache_stub).to receive(:respond_to?).with(:redis).and_return(true)
      end

      it 'returns true when visitor has not viewed today' do
        allow(cache_stub).to receive(:exist?).and_return(false)
        expect(tracker.send(:unique_today?)).to be true
      end

      it 'returns false when visitor has already viewed today' do
        allow(cache_stub).to receive(:exist?).and_return(true)
        expect(tracker.send(:unique_today?)).to be false
      end
    end

    context 'without Redis' do
      before do
        allow(ContentSignals.configuration).to receive(:redis_enabled?).and_return(false)
      end

      it 'returns true (does not track unique views)' do
        expect(tracker.send(:unique_today?)).to be true
      end
    end
  end

  describe '#track_unique_view' do
    subject(:tracker) { described_class.new(page, request, user) }

    context 'with Redis enabled' do
      let(:cache_stub) { double('cache') }

      before do
        stub_const('Rails', Class.new)
        allow(Rails).to receive(:cache).and_return(cache_stub)
        allow(ContentSignals.configuration).to receive(:redis_enabled?).and_return(true)
        allow(cache_stub).to receive(:respond_to?).with(:redis).and_return(true)
        allow(cache_stub).to receive(:write)
        allow(cache_stub).to receive(:increment)
      end

      it 'writes to cache with 24 hour expiry' do
        tracker.send(:track_unique_view)

        expect(cache_stub).to have_received(:write).with(
          anything,
          true,
          expires_in: 24.hours
        )
      end

      it 'increments daily unique counter' do
        tracker.send(:track_unique_view)

        expect(cache_stub).to have_received(:increment).with(
          "page_unique_views:Page:#{page.id}:#{Date.current}",
          1
        )
      end
    end

    context 'without Redis' do
      before do
        allow(ContentSignals.configuration).to receive(:redis_enabled?).and_return(false)
      end

      it 'returns early without writing to cache' do
        # Just verify it doesn't raise an error
        expect { tracker.send(:track_unique_view) }.not_to raise_error
      end
    end

    context 'when cache write fails' do
      let(:cache_stub) { double('cache') }
      let(:logger_stub) { double('logger') }

      before do
        stub_const('Rails', Class.new)
        allow(Rails).to receive(:cache).and_return(cache_stub)
        allow(Rails).to receive(:logger).and_return(logger_stub)
        allow(ContentSignals.configuration).to receive(:redis_enabled?).and_return(true)
        allow(cache_stub).to receive(:respond_to?).with(:redis).and_return(true)
        allow(cache_stub).to receive(:write).and_raise(StandardError, 'Redis error')
        allow(logger_stub).to receive(:error)
      end

      it 'logs error and does not raise' do
        expect { tracker.send(:track_unique_view) }.not_to raise_error
        expect(logger_stub).to have_received(:error).with(/Failed to track unique view/)
      end
    end
  end

  describe '#current_tenant_id' do
    subject(:tracker) { described_class.new(page, request, user) }

    context 'with multitenancy disabled' do
      before do
        ContentSignals.configure do |config|
          config.multitenancy = false
        end
      end

      it 'returns nil' do
        expect(tracker.send(:current_tenant_id)).to be_nil
      end
    end

    context 'with multitenancy enabled' do
      before do
        ContentSignals.configure do |config|
          config.multitenancy = true
          config.current_tenant_method = :current_tenant_id
        end
      end

      it 'calls configured method on controller' do
        controller = double('Controller', current_tenant_id: 123)
        request.env['action_controller.instance'] = controller

        expect(tracker.send(:current_tenant_id)).to eq(123)
      end

      it 'returns nil when no controller instance' do
        request.env['action_controller.instance'] = nil
        expect(tracker.send(:current_tenant_id)).to be_nil
      end

      it 'returns nil when controller does not respond to method' do
        controller = double('Controller')
        allow(controller).to receive(:respond_to?).with(:current_tenant_id, true).and_return(false)
        request.env['action_controller.instance'] = controller

        expect(tracker.send(:current_tenant_id)).to be_nil
      end

      it 'logs error and returns nil on exception' do
        logger_stub = double('logger', error: nil)
        stub_const('Rails', Class.new)
        allow(Rails).to receive(:logger).and_return(logger_stub)

        controller = double('Controller')
        allow(controller).to receive(:respond_to?).with(:current_tenant_id, true).and_return(true)
        allow(controller).to receive(:current_tenant_id).and_raise(StandardError, 'Tenant error')
        request.env['action_controller.instance'] = controller

        expect(tracker.send(:current_tenant_id)).to be_nil
        expect(logger_stub).to have_received(:error).with(/Failed to get tenant_id/)
      end
    end
  end

  describe '#compile_tracking_data' do
    subject(:tracker) { described_class.new(page, request, user) }

    before do
      allow(ContentSignals::DeviceDetectorService).to receive(:detect).and_return(
        device_type: 'desktop',
        browser: 'Chrome',
        os: 'macOS'
      )
    end

    it 'combines all tracking data' do
      data = tracker.send(:compile_tracking_data)

      expect(data).to include(
        visitor_id: "user_#{user.id}",
        ip_address: '192.168.1.100',
        user_agent: 'Mozilla/5.0',
        referrer: 'https://google.com',
        device_type: 'desktop',
        browser: 'Chrome',
        os: 'macOS'
      )
    end

    it 'does not include location fields (resolved in job)' do
      data = tracker.send(:compile_tracking_data)
      expect(data.keys).not_to include(:country_code, :country_name, :city, :region, :latitude, :longitude)
    end

    it 'includes timestamp' do
      data = tracker.send(:compile_tracking_data)
      expect(data[:viewed_at]).to be_within(1.second).of(Time.current)
    end

    it 'includes locale' do
      request.headers['Accept-Language'] = 'en-US,en;q=0.9'
      data = tracker.send(:compile_tracking_data)
      expect(data[:locale]).to eq('en-US')
    end

    it 'handles missing device data gracefully' do
      allow(ContentSignals::DeviceDetectorService).to receive(:detect).and_return(nil)

      data = tracker.send(:compile_tracking_data)

      expect(data).to include(
        visitor_id: "user_#{user.id}",
        ip_address: '192.168.1.100'
      )
    end
  end

  describe 'Turbo Native (Hotwire) mobile app integration' do
    let(:native_request) do
      MockRequest.new(
        ip: '192.168.1.100',
        user_agent: 'Turbo Native iOS/1.0',
        referrer: nil
      )
    end

    it 'sets app_platform to turbo_native and device_type to hybrid_app' do
      allow(ContentSignals::VisitorLocationService).to receive(:locate).and_return(nil)
      allow(ContentSignals::TrackPageViewJob).to receive(:perform_later)

      described_class.track(trackable: page, request: native_request, user: user)

      expect(ContentSignals::TrackPageViewJob).to have_received(:perform_later).with(
        'Page',
        page.id,
        user.id,
        hash_including(
          app_platform: 'turbo_native',
          device_type: 'hybrid_app'
        )
      )
    end
  end

  describe 'integration test' do
    let(:profile) { Profile.create!(name: 'Test Profile', page_views_count: 0) }

    it 'tracks a complete page view with all data' do
      request.headers['Accept-Language'] = 'en-US'

      allow(ContentSignals::DeviceDetectorService).to receive(:detect).and_return(
        device_type: 'mobile',
        browser: 'Safari',
        os: 'iOS'
      )

      allow(ContentSignals::TrackPageViewJob).to receive(:perform_later)

      described_class.track(trackable: profile, request: request, user: user)

      expect(ContentSignals::TrackPageViewJob).to have_received(:perform_later).with(
        'Profile',
        profile.id,
        user.id,
        hash_including(
          visitor_id: "user_#{user.id}",
          ip_address: '192.168.1.100',
          device_type: 'mobile',
          browser: 'Safari'
        )
      )
    end
  end
end
