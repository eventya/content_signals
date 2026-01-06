# Page Counters Specification

## 🚀 Status: Planning → Gem Creation

**This specification will be extracted into an open-source Ruby gem: `content_signals`**

- **Gem Name:** `content_signals` ✅ Available on RubyGems & GitHub
- **Tagline:** "Listen to signals from your content"
- **Roadmap:** See [GEM_CREATION_ROADMAP.md](GEM_CREATION_ROADMAP.md)
- **Target:** v0.1.0 release in 2 days (16 hours)
- **Use Cases:** Stejar CMS (Pages), Eventya (Profiles, Events), any polymorphic model
- **License:** MIT

---

## Overview
This document outlines the specifications for implementing content analytics to track page views, demographics, device types, and engagement metrics. Designed to work as a Rails gem with polymorphic trackable models and optional multi-tenant support.

## Counter Types

### 1. Page Views Counter

**Purpose:** Track the total number of times a page has been viewed.

**Requirements:**
- Increment counter each time a page is loaded/visited
- Track unique vs. total views (optional: distinguish between unique visitors and total page loads)
- Consider tracking views per time period (daily, weekly, monthly)
- Exclude bot/crawler traffic from counts
- Exclude admin/editor views from public counts (optional)
- Track demographics: country, city, region (using IP geolocation)
- Store language/locale preferences
- Track device types (desktop, mobile, tablet, hybrid_app)
- Track browser and OS information
- **Support hybrid mobile apps**: Recognize and track WebView/Capacitor/Cordova apps
- **App-specific tracking**: Accept device_id from mobile apps for consistent visitor identification
- **Platform identification**: Distinguish between web browser and mobile app contexts

**Data Storage:**
- `page_views_count` (integer) - Total view count on pages table
- `PageView` model for detailed tracking with:
  - `tenant_id` (bigint, optional) - For multi-tenant applications
  - `trackable_type`, `trackable_id` (polymorphic) - The model being tracked (Page, Profile, Event, etc.)
  - `user_id` (optional), `visitor_id`
  - `ip_address`, `user_agent`
  - `country_code` (string, 2 chars - e.g., 'US', 'RO')
  - `country_name` (string - e.g., 'United States', 'Romania')
  - `city` (string)
  - `region` (string - state/province)
  - `latitude`, `longitude` (decimal, optional)
  - `locale` (string - e.g., 'en-US', 'ro-RO')
  - `device_type` (string - desktop, mobile, tablet, hybrid_app)
  - `browser` (string - Chrome, Firefox, Safari, etc.)
  - `os` (string - Windows, macOS, iOS, Android, etc.)
  - `app_platform` (string - capacitor, cordova, react_native, flutter, null for web)
  - `app_version` (string - mobile app version if applicable)
  - `device_id` (string - persistent device identifier from mobile app)
  - `referrer`, `viewed_at`

**Display:**
- Show view count on page header/stats bar
- Display in page analytics dashboard with demographics breakdown
- Show top countries/cities in analytics
- Display interactive map with visitor locations
- Show device type distribution (pie chart)
- Show browser/OS statistics
- Format large numbers (e.g., 1.2K, 1.5M)
- Export demographics data as CSV/PDF

---

### 2. Followers per Page

**Purpose:** Allow users to follow/subscribe to specific pages for updates.

**Requirements:**
- Users can follow/unfollow any public page
- Track total follower count per page
- Notify followers when page content is updated (optional)
- Allow users to view list of pages they follow
- Allow page owners to view their followers

**Data Storage:**
- `followers_count` (integer) - Cached counter on pages table
- `PageFollower` model with fields:
  - `page_id` (references pages)
  - `user_id` (references users)
  - `followed_at` (datetime)
  - Unique index on `[page_id, user_id]`

**Actions:**
- `POST /pages/:id/follow` - Follow a page
- `DELETE /pages/:id/unfollow` - Unfollow a page
- `GET /pages/:id/followers` - View page followers (permission-based)
- `GET /users/:id/following_pages` - View pages user follows

**Display:**
- Show follower count on page header
- Display "Follow" / "Following" button for authenticated users
- Show follower list in page settings/analytics

---

### 3. Bookmarks Counter

**Purpose:** Track how many users have bookmarked/saved the page for later reference.

**Requirements:**
- Users can bookmark/unbookmark any page
- Track total bookmark count per page
- Allow users to view their bookmarked pages
- Bookmarks are private to each user

**Data Storage:**
- `bookmarks_count` (integer) - Cached counter on pages table
- `PageBookmark` model with fields:
  - `page_id` (references pages)
  - `user_id` (references users)
  - `bookmarked_at` (datetime)
  - `notes` (text, optional) - User's private notes about the bookmark
  - Unique index on `[page_id, user_id]`

**Actions:**
- `POST /pages/:id/bookmark` - Bookmark a page
- `DELETE /pages/:id/unbookmark` - Remove bookmark
- `GET /users/:id/bookmarks` - View user's bookmarked pages

**Display:**
- Show bookmark count on page header/stats
- Display bookmark/unbookmark icon/button for authenticated users
- Show in user's bookmark collection

---

### 4. Shares Counter

**Purpose:** Track how many times a page has been shared across different platforms.

**Requirements:**
- Track shares across multiple platforms (social media, email, copy link)
- Increment counter when share action is triggered
- Optionally track which platform was used for sharing
- Generate shareable links with tracking parameters

**Data Storage:**
- `shares_count` (integer) - Total shares counter on pages table
- Optional: `PageShare` model for detailed tracking:
  - `page_id` (references pages)
  - `user_id` (references users, nullable for anonymous)
  - `platform` (string) - twitter, facebook, linkedin, email, copy_link, etc.
  - `shared_at` (datetime)
  - `referrer` (string, optional)

**Share Platforms:**
- Twitter/X
- Facebook
- LinkedIn
- Email
- Copy link to clipboard
- WhatsApp
- Other platforms as needed

**Actions:**
- `POST /pages/:id/share` - Record a share event
  - Params: `platform` (required)
- Generate share URLs with UTM parameters for tracking

**Display:**
- Show total share count on page header
- Display share buttons with platform icons
- Show share analytics in page dashboard
- Format large numbers (e.g., 1.2K shares)

---

## Implementation Considerations

### Multi-Tenant Support

**Overview:**

The analytics system supports multi-tenant Rails applications where data must be isolated by tenant. This is essential for SaaS applications where multiple organizations share the same database.

**Configuration:**

```ruby
# config/initializers/content_signals.rb
ContentSignals.configure do |config|
  # Enable multitenancy
  config.multitenancy = true

  # Method to get current tenant ID (required if multitenancy enabled)
  config.current_tenant_method = :current_tenant_id

  # Tenant model (optional, for associations)
  config.tenant_model = 'Account' # or 'Organization', 'Company', etc.
end

# In your ApplicationController or base controller
def current_tenant_id
  Current.account_id # or however you store tenant context
end
```

**How it works:**

1. **Automatic tenant scoping** - All analytics queries are automatically scoped to current tenant:
   ```ruby
   # Automatically filtered by current tenant
   @page.analytics.top_countries
   @page.page_views_count
   ```

2. **Tenant isolation** - PageView records include `tenant_id`:
   ```ruby
   # Each view is associated with a tenant
   PageView.where(tenant_id: current_tenant_id)
   ```

3. **Cross-tenant analytics** (admin only):
   ```ruby
   # Bypass tenant scoping (requires admin permissions)
   ContentSignals.unscoped do
     PageView.group(:tenant_id).count
   end
   ```

**Multi-tenant patterns supported:**

1. **Shared database, shared schema** (row-level isolation):
   ```ruby
   # Uses tenant_id column on all tables
   config.multitenancy = true
   config.isolation_strategy = :row_level
   ```

2. **Shared database, separate schemas** (Apartment gem):
   ```ruby
   # Works with Apartment gem
   config.multitenancy = true
   config.isolation_strategy = :schema
   # tenant_id still stored for cross-schema queries
   ```

3. **Separate databases per tenant**:
   ```ruby
   # Each tenant has their own database
   config.multitenancy = false # No tenant_id needed
   ```

**Example with ActsAsTenant gem:**

```ruby
# Gemfile
gem 'acts_as_tenant'
gem 'content_signals'

# app/models/page_view.rb
class PageView < ApplicationRecord
  acts_as_tenant(:account)
  # content_signals handles the rest
end

# Automatic tenant scoping in controllers
class PagesController < ApplicationController
  set_current_tenant_through_filter
  before_action :set_current_tenant

  def set_current_tenant
    set_current_tenant(current_user.account)
  end
end
```

**Tenant-aware caching:**

```ruby
# Redis keys include tenant_id
"page_view:tenant_123:page_456:visitor_abc:2026-01-06"

# Ensures no data leakage between tenants
```

**Benefits:**
- ✅ Complete data isolation between tenants
- ✅ Works with existing multitenancy gems (ActsAsTenant, Apartment)
- ✅ Optional - can be disabled for single-tenant apps
- ✅ Prevents accidental cross-tenant data leaks
- ✅ Supports super-admin cross-tenant analytics

---

### Hybrid Mobile App Support

**Identifying Hybrid Apps:**

Hybrid apps load your Rails website inside a WebView. To properly track these:

1. **Custom Headers** - Apps should send identifying headers:
   ```javascript
   // In Capacitor/Ionic app
   import { CapacitorHttp } from '@capacitor/core';

   CapacitorHttp.request({
     url: 'https://yoursite.com/page',
     headers: {
       'X-App-Platform': 'capacitor',
       'X-App-Version': '1.2.3',
       'X-Device-ID': 'unique-device-uuid'
     }
   });

   // Or inject headers in WebView
   webView.setWebViewClient(new WebViewClient() {
     @Override
     public WebResourceResponse shouldInterceptRequest(WebView view, String url) {
       // Add custom headers to all requests
     }
   });
   ```

2. **URL Parameters** - Alternative approach for initial load:
   ```
   https://yoursite.com/page?app_platform=capacitor&device_id=abc123&app_version=1.2.3
   ```

3. **JavaScript Detection** - Detect WebView in frontend:
   ```javascript
   // Check for Capacitor
   const isCapacitor = window.Capacitor !== undefined;

   // Check for Cordova
   const isCordova = window.cordova !== undefined;

   // Check for generic WebView
   const isWebView = /wv|WebView|; wv\)/.test(navigator.userAgent);

   // Send to analytics endpoint
   if (isCapacitor || isCordova || isWebView) {
     fetch('/api/analytics/identify', {
       method: 'POST',
       headers: { 'Content-Type': 'application/json' },
       body: JSON.stringify({
         app_platform: isCapacitor ? 'capacitor' : isCordova ? 'cordova' : 'webview',
         device_id: localStorage.getItem('device_id') || generateDeviceId(),
         app_version: window.APP_VERSION
       })
     });
   }
   ```

**Visitor Identification for Apps:**

```ruby
# app/services/page_view_tracker.rb
def identify_visitor
  # 1. Use authenticated user ID if available
  return "user_#{@user.id}" if @user

  # 2. Use device_id from mobile app (most reliable for apps)
  device_id = @request.headers['X-Device-ID'] || @request.params[:device_id]
  return "device_#{device_id}" if device_id.present?

  # 3. Use cookie for web browsers
  cookie_id = @request.cookie_jar.signed[:visitor_id]
  return cookie_id if cookie_id.present?

  # 4. Fallback to IP + User Agent hash
  "anon_#{Digest::SHA256.hexdigest("#{@request.ip}:#{@request.user_agent}")[0..15]}"
end

def detect_app_context
  {
    app_platform: @request.headers['X-App-Platform'] || detect_platform_from_ua,
    app_version: @request.headers['X-App-Version'],
    device_id: @request.headers['X-Device-ID'] || @request.params[:device_id]
  }
end

def detect_platform_from_ua
  ua = @request.user_agent.to_s.downcase
  return 'capacitor' if ua.include?('capacitor')
  return 'cordova' if ua.include?('cordova')
  return 'react_native' if ua.include?('react-native')
  return 'flutter' if ua.include?('flutter')
  return 'webview' if ua.match?(/wv|webview/)
  nil
end
```

**Device Type Detection:**

```ruby
# app/services/device_detector_service.rb
def self.detect(user_agent, app_platform: nil)
  browser = Browser.new(user_agent)

  device_type = if app_platform.present?
    'hybrid_app' # It's from a mobile app
  elsif browser.device.mobile?
    'mobile'
  elsif browser.device.tablet?
    'tablet'
  else
    'desktop'
  end

  {
    device_type: device_type,
    browser: browser.name,
    browser_version: browser.version,
    os: browser.platform.name,
    os_version: browser.platform.version,
    is_webview: browser.device.mobile? && user_agent.match?(/wv|WebView/i)
  }
end
```

**Updated Migration:**

```ruby
# Add app-specific columns to page_views table
create_table :page_views do |t|
  # ... existing columns ...

  # Hybrid app support
  t.string :app_platform, limit: 20  # capacitor, cordova, react_native, flutter, null
  t.string :app_version, limit: 20   # e.g., "1.2.3"
  t.string :device_id                # Persistent device identifier from app

  # ... rest of columns ...
end

add_index :page_views, :app_platform
add_index :page_views, :device_id
```

**Benefits:**
- ✅ Consistent visitor tracking across app sessions
- ✅ Distinguish app users from web users
- ✅ Track app version adoption
- ✅ Analyze app vs web engagement
- ✅ Debug app-specific issues

---

### Geolocation Services - Detailed Comparison

#### Recommended: MaxMind GeoLite2 (Free) or GeoIP2 (Paid)

**Why MaxMind?**
- ✅ **Local database** - No API calls, no rate limits, instant lookups (1-2ms)
- ✅ **Privacy-friendly** - Data never leaves your server
- ✅ **Cost-effective** - Free tier with decent accuracy (~95% country, ~80% city)
- ✅ **Battle-tested** - Used by Netflix, Cloudflare, AWS
- ✅ **Offline-capable** - Works without internet connection
- ✅ **GDPR compliant** - No data sharing with third parties

**MaxMind Options:**

| Feature | GeoLite2 City (Free) | GeoIP2 City (Paid) |
|---------|---------------------|-------------------|
| Price | Free | $40/month or $0.008/lookup |
| Country accuracy | ~95% | ~99.8% |
| City accuracy | ~80% | ~96% |
| Updates | Weekly | Daily |
| IP coverage | ~200M IPs | ~400M IPs |
| Additional data | Basic | ISP, connection type, domain |
| Support | Community | Commercial |

**Setup Steps:**

1. **Create MaxMind account** (free): https://www.maxmind.com/en/geolite2/signup
2. **Generate license key** in account dashboard
3. **Download database** (GeoLite2-City.mmdb, ~70MB)
4. **Store in:** `db/GeoLite2-City.mmdb` (add to .gitignore!)
5. **Set up weekly auto-updates** (via cron job)

**Alternatives (if MaxMind doesn't work for you):**

| Service | Type | Free Tier | Accuracy | Best For |
|---------|------|-----------|----------|----------|
| **IPinfo.io** | API | 50k/month | Excellent | Low-traffic sites |
| **IP2Location** | Database | LITE version | Good | MaxMind alternative |
| **ipapi.co** | API | 1k/day | Good | Quick prototyping |
| **ipgeolocation.io** | API | 30k/month | Good | More generous free tier |
| **AbstractAPI** | API | 20k/month | Good | Simple API |

**When to use APIs instead of local database:**
- Very low traffic (<1k requests/month)
- Don't want to manage database updates
- Need additional data (timezone, currency, threat detection)
- Prototyping/development

**Implementation approach:**
```ruby
# Gemfile
gem 'maxminddb' # For local GeoIP2 database
gem 'browser'   # For device/browser detection

# Download GeoLite2 database:
# 1. Sign up at https://www.maxmind.com/en/geolite2/signup
# 2. Generate license key
# 3. Download GeoLite2-City.mmdb
# 4. Place in: db/GeoLite2-City.mmdb

# Auto-update script (run weekly via cron)
# lib/tasks/maxmind.rake
namespace :maxmind do
  desc "Update GeoLite2 database"
  task :update do
    require 'net/http'
    require 'zlib'
    require 'rubygems/package'

    license_key = ENV['MAXMIND_LICENSE_KEY']
    edition_id = 'GeoLite2-City'
    url = "https://download.maxmind.com/app/geoip_download?edition_id=#{edition_id}&license_key=#{license_key}&suffix=tar.gz"

    # Download, extract, and move to db/
    # (implementation details omitted for brevity)
    puts "GeoLite2 database updated successfully"
  end
end

# app/services/visitor_location_service.rb
class VisitorLocationService
  DB_PATH = Rails.root.join('db', 'GeoLite2-City.mmdb')

  def self.locate(ip_address)
    return nil if ip_address.blank? || local_ip?(ip_address)

    # Initialize database connection (cached in production)
    db = @db ||= MaxMindDB.new(DB_PATH)
    result = db.lookup(ip_address)

    return nil unless result.found?

    {
      country_code: result.country.iso_code,
      country_name: result.country.name,
      city: result.city.name,
      region: result.subdivisions.most_specific&.name,
      latitude: result.location.latitude,
      longitude: result.location.longitude
    }
  rescue MaxMindDB::Error => e
    Rails.logger.error "MaxMind lookup error: #{e.message}"
    nil
  rescue => e
    Rails.logger.error "Geolocation error: #{e.message}"
    nil
  end

  def self.local_ip?(ip)
    return true if ip.nil?
    ip.start_with?('127.', '192.168.', '10.', '172.', 'fc00:', 'fe80:') ||
    ip == '::1' ||
    ip == 'localhost'
  end

  # Fallback to API if database not available
  def self.locate_via_api(ip_address)
    return nil if ip_address.blank? || local_ip?(ip_address)

    # Using IPinfo.io as fallback
    response = HTTP.get("https://ipinfo.io/#{ip_address}/json", params: { token: ENV['IPINFO_TOKEN'] })
    data = JSON.parse(response.body)

    return nil unless data['country']

    lat, lng = data['loc']&.split(',')&.map(&:to_f)

    {
      country_code: data['country'],
      country_name: ISO3166::Country[data['country']]&.name,
      city: data['city'],
      region: data['region'],
      latitude: lat,
      longitude: lng
    }
  rescue => e
    Rails.logger.error "API geolocation error: #{e.message}"
    nil
  end
end

# Alternative: IP2Location implementation
# gem 'ip2location_ruby'
class VisitorLocationServiceIP2Location
  DB_PATH = Rails.root.join('db', 'IP2LOCATION-LITE-DB5.BIN')

  def self.locate(ip_address)
    return nil if ip_address.blank?

    db = IP2Location::Database.new(DB_PATH, :file_io)
    result = db.get_all(ip_address)

    return nil if result[:status] != 'OK'

    {
      country_code: result[:country_short],
      country_name: result[:country_long],
      city: result[:city],
      region: result[:region],
      latitude: result[:latitude],
      longitude: result[:longitude]
    }
  rescue => e
    Rails.logger.error "IP2Location error: #{e.message}"
    nil
  end
end

# app/services/device_detector_service.rb
class DeviceDetectorService
  def self.detect(user_agent, app_platform: nil)
    browser = Browser.new(user_agent)

    {
      device_type: detect_device_type(browser, app_platform),
      browser: browser.name,
      browser_version: browser.version,
      os: browser.platform.name,
      os_version: browser.platform.version,
      is_webview: is_webview?(user_agent)
    }
  end

  def self.detect_device_type(browser, app_platform)
    # If it's from a mobile app, always mark as hybrid_app
    return 'hybrid_app' if app_platform.present?
    return 'mobile' if browser.device.mobile?
    return 'tablet' if browser.device.tablet?

    'desktop'
  end

  def self.is_webview?(user_agent)
    ua = user_agent.to_s.downcase
    ua.match?(/wv|webview|; wv\)/)
  end
end
```

### Counter Cache
- Use Rails counter_cache for performance
- Update counters using `increment_counter` / `decrement_counter`
- Consider using background jobs for non-critical counter updates

### Privacy & Permissions
- Respect user privacy settings
- Allow users to opt-out of tracking (where applicable)
- Implement proper authorization for viewing follower lists
- Consider GDPR compliance for personal data

### Performance
- Cache counter values to avoid N+1 queries
- Use database indexes on foreign keys
- Consider Redis for real-time counter updates
- Implement rate limiting on counter actions to prevent abuse

### Analytics Integration
- Store historical data for trend analysis
- Generate reports on engagement metrics
- Export data for external analytics tools
- Track counter changes over time

### User Interface
- Use icons to represent each counter type
- Implement loading states for counter actions
- Show confirmation messages for user actions
- Use optimistic UI updates where appropriate
- Make counters clickable to show more details (where applicable)

---

## Database Migrations

### Add counter columns to pages table
```ruby
add_column :pages, :page_views_count, :integer, default: 0, null: false
add_column :pages, :followers_count, :integer, default: 0, null: false
add_column :pages, :bookmarks_count, :integer, default: 0, null: false
add_column :pages, :shares_count, :integer, default: 0, null: false

add_index :pages, :page_views_count
add_index :pages, :followers_count
add_index :pages, :bookmarks_count
add_index :pages, :shares_count
```

### Create association tables
```ruby
# PageFollower
create_table :page_followers do |t|
  t.references :page, null: false, foreign_key: true
  t.references :user, null: false, foreign_key: true
  t.datetime :followed_at, null: false
  t.timestamps
end
add_index :page_followers, [:page_id, :user_id], unique: true

# PageBookmark
create_table :page_bookmarks do |t|
  t.references :page, null: false, foreign_key: true
  t.references :user, null: false, foreign_key: true
  t.text :notes
  t.datetime :bookmarked_at, null: false
  t.timestamps
end
add_index :page_bookmarks, [:page_id, :user_id], unique: true

# PageView - with demographics and multitenancy
create_table :content_signals_page_views do |t|
  # Multi-tenancy support (optional)
  t.references :tenant, null: true, index: true

  # Polymorphic trackable (Page, Profile, Event, etc.)
  t.string :trackable_type, null: false
  t.bigint :trackable_id, null: false

  t.references :user, null: true, foreign_key: true
  t.string :visitor_id, null: false
  t.string :ip_address
  t.string :user_agent
  t.string :referrer

  # Demographics
  t.string :country_code, limit: 2
  t.string :country_name
  t.string :city
  t.string :region
  t.decimal :latitude, precision: 10, scale: 6
  t.decimal :longitude, precision: 10, scale: 6
  t.string :locale, limit: 10

  # Device info
  t.string :device_type, limit: 20
  t.string :browser, limit: 50
  t.string :os, limit: 50

  # Hybrid app support
  t.string :app_platform, limit: 20    # capacitor, cordova, react_native, flutter
  t.string :app_version, limit: 20     # e.g., "1.2.3"
  t.string :device_id                  # Persistent device identifier from app

  t.datetime :viewed_at, null: false
  t.timestamps

  # Indexes for performance
  t.index [:trackable_type, :trackable_id, :viewed_at], name: 'index_page_views_on_trackable_and_date'
  t.index [:trackable_type, :trackable_id, :country_code], name: 'index_page_views_on_trackable_and_country'
  t.index [:trackable_type, :trackable_id, :city], name: 'index_page_views_on_trackable_and_city'
  t.index [:trackable_type, :trackable_id, :device_type], name: 'index_page_views_on_trackable_and_device'
  t.index [:trackable_type, :trackable_id, :app_platform], name: 'index_page_views_on_trackable_and_platform'
  t.index [:tenant_id, :viewed_at], name: 'index_page_views_on_tenant_and_date'
  t.index [:visitor_id, :viewed_at]
  t.index [:device_id]
end

# PageShare (optional, for detailed tracking)
create_table :page_shares do |t|
  t.references :page, null: false, foreign_key: true
  t.references :user, null: true, foreign_key: true
  t.string :platform, null: false
  t.string :referrer
  t.datetime :shared_at, null: false
  t.timestamps
end
add_index :page_shares, :page_id
add_index :page_shares, :platform

# PageViewStats - aggregated demographics
create_table :page_view_stats do |t|
  t.references :page, null: false, foreign_key: true
  t.integer :period_type, null: false # daily, weekly, monthly
  t.datetime :period_start, null: false
  t.integer :total_views, default: 0
  t.integer :unique_views, default: 0

  # Top countries (JSON or separate table)
  t.jsonb :country_stats # { "US": 1234, "RO": 567, ... }
  t.jsonb :city_stats    # { "New York": 234, "Bucharest": 123, ... }
  t.jsonb :device_stats  # { "mobile": 789, "desktop": 456, "tablet": 12 }

  t.timestamps

  t.index [:page_id, :period_type, :period_start], unique: true
end
```

---

## API Endpoints Summary

```
# Page Views (read-only, auto-incremented on page load)
GET /cms/pages/:id/views
GET /cms/pages/:id/analytics/demographics
GET /cms/pages/:id/analytics/countries
GET /cms/pages/:id/analytics/cities
GET /cms/pages/:id/analytics/devices

# Followers
POST   /cms/pages/:id/follow
DELETE /cms/pages/:id/unfollow
GET    /cms/pages/:id/followers
GET    /cms/pages/:id/following_status

# Bookmarks
POST   /cms/pages/:id/bookmark
DELETE /cms/pages/:id/unbookmark
GET    /users/bookmarks

# Shares
POST   /cms/pages/:id/share
GET    /cms/pages/:id/shares/stats
```

---

## Complete Implementation Example

### 1. Enhanced PageViewTracker Service

```ruby
# app/services/page_view_tracker.rb
class PageViewTracker
  def self.track(page:, user:, request:)
    new(page, user, request).track
  end

  def initialize(page, user, request)
    @page = page
    @user = user
    @request = request
    @visitor_id = identify_visitor
  end

  def track
    # Always increment total views (fast, non-blocking)
    @page.increment!(:page_views_count)

    # Track unique view if first time today
    track_unique_view if unique_today?

    # Gather all tracking data
    tracking_data = compile_tracking_data

    # Store detailed view record asynchronously
    TrackPageViewJob.perform_later(@page.id, @user&.id, tracking_data)
  end

  private

  def identify_visitor
    # 1. Authenticated user (most reliable)
    return "user_#{@user.id}" if @user

    # 2. Device ID from mobile app (persistent across app sessions)
    device_id = @request.headers['X-Device-ID'] || @request.params[:device_id]
    return "device_#{device_id}" if device_id.present?

    # 3. Browser cookie (works for web, not reliable in WebViews)
    cookie_id = @request.cookie_jar.signed[:visitor_id]
    return cookie_id if cookie_id.present?

    # 4. Fallback to IP + User Agent hash
    "anon_#{Digest::SHA256.hexdigest("#{@request.ip}:#{@request.user_agent}")[0..15]}"
  end

  def unique_today?
    key = "page_view:#{@page.id}:#{@visitor_id}:#{Date.current}"
    !Rails.cache.exist?(key)
  end

  def track_unique_view
    key = "page_view:#{@page.id}:#{@visitor_id}:#{Date.current}"
    Rails.cache.write(key, true, expires_in: 24.hours)

    Rails.cache.increment("page_unique_views:#{@page.id}:#{Date.current}", 1)
  end

  def compile_tracking_data
    location_data = VisitorLocationService.locate(@request.ip)
    app_context = detect_app_context
    device_data = DeviceDetectorService.detect(
      @request.user_agent,
      app_platform: app_context[:app_platform]
    )

    {
      tenant_id: current_tenant_id,
      trackable_type: @page.class.name,
      trackable_id: @page.id,
      visitor_id: @visitor_id,
      ip_address: @request.ip,
      user_agent: @request.user_agent,
      referrer: @request.referrer,
      locale: @request.headers['Accept-Language']&.split(',')&.first || I18n.locale.to_s,
      viewed_at: Time.current,
      app_platform: app_context[:app_platform],
      app_version: app_context[:app_version],
      device_id: app_context[:device_id]
    }.merge(location_data || {}).merge(device_data || {})
  end

  def current_tenant_id
    return nil unless ContentSignals.configuration.multitenancy?

    # Call the configured method to get tenant ID
    method_name = ContentSignals.configuration.current_tenant_method
    @request.env['action_controller.instance']&.send(method_name)
  rescue => e
    Rails.logger.error "Failed to get tenant_id: #{e.message}"
    nil

  def detect_platform_from_ua
    ua = @request.user_agent.to_s.downcase
    return 'capacitor' if ua.include?('capacitor')
    return 'cordova' if ua.include?('cordova')
    return 'react_native' if ua.include?('react-native')
    return 'flutter' if ua.include?('flutter')
    return 'webview' if ua.match?(/wv|webview/)
    nil
  end
end
```

### 2. Background Job for Detailed Tracking

```ruby
# app/jobs/track_page_view_job.rb
class TrackPageViewJob < ApplicationJob
  queue_as :default

  # Retry on database errors but not on validation errors
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
  discard_on ActiveRecord::RecordInvalid

  def perform(trackable_type, trackable_id, user_id, tracking_data)
    ContentSignals::PageView.create!(
      tenant_id: tracking_data[:tenant_id],
      trackable_type: trackable_type,
      trackable_id: trackable_id,
      user_id: user_id,
      visitor_id: tracking_data[:visitor_id],
      ip_address: tracking_data[:ip_address],
      user_agent: tracking_data[:user_agent],
      referrer: tracking_data[:referrer],
      country_code: tracking_data[:country_code],
      country_name: tracking_data[:country_name],
      city: tracking_data[:city],
      region: tracking_data[:region],
      latitude: tracking_data[:latitude],
      longitude: tracking_data[:longitude],
      locale: tracking_data[:locale],
      device_type: tracking_data[:device_type],
      browser: tracking_data[:browser],
      os: tracking_data[:os],
      app_platform: tracking_data[:app_platform],
      app_version: tracking_data[:app_version],
      device_id: tracking_data[:device_id],
      viewed_at: tracking_data[:viewed_at]
    )
  rescue => e
    Rails.logger.error "Failed to track page view: #{e.message}"
    # Optionally send to error tracking service (Sentry, Rollbar, etc.)
  end
end
```

### 3. PageView Model with Scopes

```ruby
# app/models/content_signals/page_view.rb
module ContentSignals
  class PageView < ApplicationRecord
    self.table_name = 'content_signals_page_views'

    # Associations
    belongs_to :trackable, polymorphic: true
    belongs_to :tenant, optional: true
    belongs_to :user, optional: true

    # Multi-tenant scoping (automatic)
    if ContentSignals.configuration.multitenancy?
      default_scope -> { where(tenant_id: ContentSignals.current_tenant_id) }

      # Bypass tenant scoping (admin use only)
      scope :unscoped_by_tenant, -> { unscope(where: :tenant_id) }
    end

    # Time period scopes
  scope :today, -> { where('viewed_at >= ?', Time.current.beginning_of_day) }
  scope :yesterday, -> { where(viewed_at: 1.day.ago.all_day) }
  scope :this_week, -> { where('viewed_at >= ?', Time.current.beginning_of_week) }
  scope :last_week, -> { where(viewed_at: 1.week.ago.beginning_of_week..1.week.ago.end_of_week) }
  scope :this_month, -> { where('viewed_at >= ?', Time.current.beginning_of_month) }
  scope :last_30_days, -> { where('viewed_at >= ?', 30.days.ago) }

  # Device scopes
  scope :mobile, -> { where(device_type: 'mobile') }
  scope :desktop, -> { where(device_type: 'desktop') }
  scope :tablet, -> { where(device_type: 'tablet') }

  # Location scopes
  scope :from_country, ->(country_code) { where(country_code: country_code) }
  scope :from_city, ->(city) { where(city: city) }

  # Analytics methods
  def self.unique_count(period = :today)
    send(period).distinct.count(:visitor_id)
  end

  def self.top_countries(limit = 10)
    where.not(country_name: nil)
      .group(:country_code, :country_name)
      .order('count_id DESC')
      .limit(limit)
      .count(:id)
  end

  def self.top_cities(limit = 10)
    where.not(city: nil)
      .group(:city, :country_name)
      .order('count_id DESC')
      .limit(limit)
      .count(:id)
  end

  def self.device_breakdown
    group(:device_type)
      .count(:id)
      .transform_keys { |k| k || 'unknown' }
  end

  def self.browser_breakdown
    group(:browser)
      .order('count_id DESC')
      .count(:id)
      .transform_keys { |k| k || 'unknown' }
  end

  def self.hourly_distribution
    group("EXTRACT(HOUR FROM viewed_at)::integer")
      .order("EXTRACT(HOUR FROM viewed_at)::integer")
      .count(:id)
  end

  # For map visualization - returns array of [lat, lng, count]
  def self.location_heatmap
    where.not(latitude: nil, longitude: nil)
      .group(:latitude, :longitude)
      .count(:id)
      .map { |(lat, lng), count| { lat: lat, lng: lng, count: count } }
  end
end
```

### 4. Controller Integration

```ruby
# app/controllers/concerns/trackable_page_views.rb
module TrackablePageViews
  extend ActiveSupport::Concern

  included do
    after_action :track_page_view, only: [:show]
  end

  private

  def track_page_view
    return if should_skip_tracking?

    PageViewTracker.track(
      page: @page,
      user: current_user,
      request: request
    )
  end

  def should_skip_tracking?
    bot_request? ||
    admin_viewing? ||
    preview_mode? ||
    @page.nil?
  end

  def bot_request?
    browser = Browser.new(request.user_agent)
    browser.bot? || browser.search_engine?
  rescue
    false
  end

  def admin_viewing?
    current_user&.admin? || can_edit_page?
  end

  def can_edit_page?
    return false unless current_user && @page
    current_user.can?(:edit, @page)
  end

  def preview_mode?
    params[:preview].present? || session[:preview_mode]
  end
end

# Include in your pages controller
# app/controllers/pages_controller.rb
class PagesController < ApplicationController
  include TrackablePageViews

  def show
    @page = Page.find(params[:id])
    # ... rest of your show action
  end
end
```

### 5. Analytics Service

```ruby
# app/services/page_analytics_service.rb
class PageAnalyticsService
  attr_reader :page, :period

  def initialize(page, period: :last_30_days)
    @page = page
    @period = period
  end

  def stats
    views = page.page_views.send(period)

    {
      total_views: views.count,
      unique_views: views.distinct.count(:visitor_id),
      demographics: {
        countries: views.top_countries(10),
        cities: views.top_cities(10),
        map_data: views.location_heatmap
      },
      devices: {
        types: views.device_breakdown,
        browsers: views.browser_breakdown.first(10)
      },
      timeline: views.group_by_day(:viewed_at, range: period_range).count,
      hourly_pattern: views.hourly_distribution,
      top_referrers: top_referrers(views)
    }
  end

  def export_csv
    require 'csv'

    CSV.generate(headers: true) do |csv|
      csv << [
        'Date', 'Country', 'City', 'Device', 'Browser',
        'OS', 'Referrer', 'Unique Visitor'
      ]

      page.page_views.send(period).find_each do |view|
        csv << [
          view.viewed_at.to_date,
          view.country_name,
          view.city,
          view.device_type,
          view.browser,
          view.os,
          view.referrer,
          view.visitor_id
        ]
      end
    end
  end

  private

  def period_range
    case period
    when :today then Date.current..Date.current
    when :this_week then Date.current.beginning_of_week..Date.current
    when :this_month then Date.current.beginning_of_month..Date.current
    when :last_30_days then 30.days.ago.to_date..Date.current
    else 30.days.ago.to_date..Date.current
    end
  end

  def top_referrers(views)
    views.where.not(referrer: nil)
      .group(:referrer)
      .order('count_id DESC')
      .limit(10)
      .count(:id)
  end
end
```

### 6. Analytics Controller

```ruby
# app/controllers/cms/page_analytics_controller.rb
module Cms
  class PageAnalyticsController < Cms::BaseController
    before_action :set_page
    before_action :authorize_analytics_access

    def show
      @period = params[:period]&.to_sym || :last_30_days
      @analytics = PageAnalyticsService.new(@page, period: @period)
      @stats = @analytics.stats
    end

    def demographics
      @period = params[:period]&.to_sym || :last_30_days
      views = @page.page_views.send(@period)

      render json: {
        countries: views.top_countries(20),
        cities: views.top_cities(20),
        map_data: views.location_heatmap
      }
    end

    def devices
      @period = params[:period]&.to_sym || :last_30_days
      views = @page.page_views.send(@period)

      render json: {
        types: views.device_breakdown,
        browsers: views.browser_breakdown
      }
    end

    def export
      @period = params[:period]&.to_sym || :last_30_days
      analytics = PageAnalyticsService.new(@page, period: @period)

      send_data analytics.export_csv,
        filename: "page-#{@page.id}-analytics-#{Date.current}.csv",
        type: 'text/csv'
    end

    private

    def set_page
      @page = Page.find(params[:page_id])
    end

    def authorize_analytics_access
      authorize! :read_analytics, @page
    end
  end
end

# config/routes.rb
namespace :cms do
  resources :pages do
    resource :analytics, only: [:show], controller: 'page_analytics' do
      get :demographics
      get :devices
      get :export
    end
  end
end
```

### 7. Daily Aggregation Job

```ruby
# app/jobs/aggregate_page_views_job.rb
class AggregatePageViewsJob < ApplicationJob
  queue_as :low_priority

  def perform(date = Date.yesterday)
    Page.find_each do |page|
      aggregate_for_page(page, date)
    end
  end

  private

  def aggregate_for_page(page, date)
    views = page.page_views.where(viewed_at: date.all_day)

    return if views.empty?

    PageViewStat.create_or_find_by!(
      page: page,
      period_type: :daily,
      period_start: date.beginning_of_day
    ).update!(
      total_views: views.count,
      unique_views: views.distinct.count(:visitor_id),
      country_stats: aggregate_countries(views),
      city_stats: aggregate_cities(views),
      device_stats: aggregate_devices(views)
    )
  end

  def aggregate_countries(views)
    views.where.not(country_code: nil)
      .group(:country_code, :country_name)
      .count(:id)
      .transform_keys { |(code, name)| "#{code}:#{name}" }
  end

  def aggregate_cities(views)
    views.where.not(city: nil)
      .group(:city)
      .count(:id)
  end

  def aggregate_devices(views)
    views.group(:device_type).count(:id)
  end
end

# Schedule with sidekiq-cron or whenever
# config/schedule.yml (for sidekiq-cron)
aggregate_page_views:
  cron: "0 2 * * *"  # Run at 2 AM daily
  class: "AggregatePageViewsJob"
```

### 8. View Example (Analytics Dashboard)

```erb
<!-- app/views/cms/page_analytics/show.html.erb -->
<div class="analytics-dashboard">
  <div class="analytics-header">
    <h2>Analytics for <%= @page.title %></h2>

    <%= form_with url: cms_page_analytics_path(@page), method: :get, class: "period-selector" do |f| %>
      <%= f.select :period,
        options_for_select([
          ['Today', 'today'],
          ['This Week', 'this_week'],
          ['This Month', 'this_month'],
          ['Last 30 Days', 'last_30_days']
        ], @period),
        {},
        onchange: 'this.form.submit()' %>
    <% end %>

    <%= link_to "Export CSV", export_cms_page_analytics_path(@page, period: @period),
        class: "btn btn--outline" %>
  </div>

  <div class="analytics-stats">
    <div class="stat-card">
      <h3>Total Views</h3>
      <p class="stat-value"><%= number_with_delimiter(@stats[:total_views]) %></p>
    </div>

    <div class="stat-card">
      <h3>Unique Visitors</h3>
      <p class="stat-value"><%= number_with_delimiter(@stats[:unique_views]) %></p>
    </div>
  </div>

  <div class="analytics-charts">
    <!-- Timeline Chart -->
    <div class="chart-container">
      <h3>Views Over Time</h3>
      <canvas id="timeline-chart"
              data-timeline="<%= @stats[:timeline].to_json %>"></canvas>
    </div>

    <!-- Device Breakdown -->
    <div class="chart-container">
      <h3>Device Types</h3>
      <canvas id="device-chart"
              data-devices="<%= @stats[:devices][:types].to_json %>"></canvas>
    </div>

    <!-- Top Countries -->
    <div class="chart-container">
      <h3>Top Countries</h3>
      <table class="analytics-table">
        <% @stats[:demographics][:countries].each do |(code, name), count| %>
          <tr>
            <td><%= name %> (<%= code %>)</td>
            <td><%= number_with_delimiter(count) %></td>
          </tr>
        <% end %>
      </table>
    </div>

    <!-- Location Map -->
    <div class="chart-container full-width">
      <h3>Visitor Locations</h3>
      <div id="visitor-map"
           data-locations="<%= @stats[:demographics][:map_data].to_json %>"
           style="height: 500px;"></div>
    </div>
  </div>
</div>

<!-- Include Chart.js and Leaflet for visualizations -->
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
```

This complete implementation provides:
- ✅ Fast, non-blocking view tracking
- ✅ Detailed demographics collection
- ✅ Background processing for heavy operations
- ✅ Comprehensive analytics with scopes
- ✅ Daily aggregation for performance
- ✅ CSV export functionality
- ✅ Ready-to-use dashboard views
- ✅ Error handling and retries

---

## Analytics Queries Examples

```ruby
# Top countries for a page
PageView.where(page: @page)
  .group(:country_name)
  .order('count_id DESC')
  .limit(10)
  .count(:id)

# Top cities
PageView.where(page: @page)
  .where.not(city: nil)
  .group(:city, :country_name)
  .order('count_id DESC')
  .limit(10)
  .count(:id)

# Device breakdown
PageView.where(page: @page)
  .group(:device_type)
  .count(:id)

# Browser stats
PageView.where(page: @page)
  .group(:browser)
  .order('count_id DESC')
  .count(:id)

# Views over time with location
PageView.where(page: @page, country_code: 'US')
  .group_by_day(:viewed_at)
  .count

# Aggregated stats (faster for large datasets)
PageViewStat.where(page: @page, period_type: :daily)
  .where('period_start >= ?', 30.days.ago)
  .pluck(:period_start, :total_views, :country_stats)
```

---

## 🎯 Next Steps: Gem Creation

### Decision Checklist
- [ ] Check gem name availability on RubyGems.org
- [ ] Decide: Build gem now (2 days) or extract later (3-6 months)?
- [ ] Review [GEM_CREATION_ROADMAP.md](GEM_CREATION_ROADMAP.md) for full plan
- [ ] Consider: MVP (10 hours) vs Full Release (16 hours)

### If Proceeding with Gem:
1. [ ] Check name: `modest_analytics` on RubyGems
2. [ ] Create GitHub repo: `modest_analytics`
3. [ ] Run: `bundle gem modest_analytics --test=rspec --ci=github --mit`
4. [ ] Copy code from this spec to gem structure
5. [ ] Write tests (RSpec)
6. [ ] Write README & documentation
7. [ ] Publish to RubyGems v0.1.0
8. [ ] Integrate into Stejar CMS
9. [ ] Integrate into Eventya
10. [ ] Announce release!

### Gem Features (Confirmed)
- ✅ Polymorphic trackable (works with any model)
- ✅ Multi-tenant support (optional tenant_id scoping)
- ✅ Hybrid mobile app support (Capacitor, Cordova, React Native, Flutter)
- ✅ IP geolocation (MaxMind GeoLite2)
- ✅ Device detection (mobile, desktop, tablet, browser, OS)
- ✅ Background job processing (async PageView creation)
- ✅ Redis unique tracking (24-hour deduplication)
- ✅ Counter caching for performance
- ✅ Privacy-focused (local IP database, bot exclusion)

### Time Estimate
- **MVP:** 10-12 hours (basic tracking + simple queries)
- **Full Release:** 16 hours (including comprehensive tests & docs)
- **Integration:** 2-4 hours per app (Stejar, Eventya)

### Resources
- 📋 **Full Roadmap:** [GEM_CREATION_ROADMAP.md](GEM_CREATION_ROADMAP.md)
- 📊 **This Spec:** Complete implementation details (you are here)
- 🌐 **MaxMind:** Free GeoLite2 database for geolocation
- 🔧 **Browser Gem:** Device/browser detection
- ⚡ **Redis:** Optional unique visitor deduplication

---

**Ready to ship! 🚢**

---

## Testing Requirements

- Test counter increments/decrements
- Test counter cache consistency
- Test uniqueness constraints
- Test permissions and authorization
- Test rate limiting
- Test concurrent updates
- Test counter reset/recalculation
