# ContentSignals

**Listen to signals from your content.**

A Rails engine for tracking page views and content engagement with rich analytics. Track views on any model (Pages, Posts, Events, Profiles) with demographics, device detection, and multi-tenant support.

## Features

- 📊 **Page view tracking** with visitor identification
- 🌍 **Geolocation** (country, city, region) via MaxMind GeoLite2
- 📱 **Device detection** (mobile, tablet, desktop, hybrid apps)
- 🏢 **Multi-tenant support** (optional)
- 🤖 **Bot filtering** (automatically excludes crawlers)
- 🔄 **Background processing** (non-blocking with ActiveJob)
- 📈 **Rich analytics** with time-based scopes and aggregations
- 🎯 **Polymorphic tracking** (works with any model)
- 📲 **Hybrid app support** (Capacitor, Cordova, React Native, Flutter)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'content_signals'
```

Then execute:

```bash
bundle install
```

Run the install generator:

```bash
rails generate content_signals:install
rails db:migrate
```

## Usage

### Basic Setup

#### 1. Add counter cache column to your trackable models

Add a `page_views_count` column to any model you want to track views for:

```ruby
# Migration example for Pages
class AddPageViewsCountToPages < ActiveRecord::Migration[7.0]
  def change
    add_column :pages, :page_views_count, :integer, default: 0, null: false
    add_index :pages, :page_views_count
  end
end
```

**Important:** The counter column must be named `page_views_count` (following Rails counter_cache conventions). The ContentSignals PageView model uses `counter_cache: :page_views_count` to automatically increment this column when view records are created.

For multiple trackable models:

```ruby
# Add to any models you want to track
add_column :posts, :page_views_count, :integer, default: 0, null: false
add_column :events, :page_views_count, :integer, default: 0, null: false
add_column :profiles, :page_views_count, :integer, default: 0, null: false
```

#### 2. Include tracking in your controller

```ruby
class PagesController < ApplicationController
  include ContentSignals::TrackablePageViews

  def show
    @page = Page.find(params[:id])
    # Page views are automatically tracked!
  end
end
```

**How it works:**
1. When a user visits a tracked page, the concern triggers tracking
2. A background job is enqueued to create a detailed PageView record
3. The `page_views_count` counter is automatically incremented via Rails counter_cache if the 'hit' is unique for the day
4. No blocking - the user gets instant response while tracking happens asynchronously

That's it! Page views will now be tracked automatically with:
- Total view counter via counter_cache (incremented when PageView record is created)
- Detailed PageView records with demographics (via background job)
- Visitor identification (authenticated users, device IDs, or anonymous)
- Device and location data
- Bot filtering

### Configuration

Create an initializer `config/initializers/content_signals.rb`:

```ruby
ContentSignals.configure do |config|
  # Multi-tenancy (optional)
  config.multitenancy = false
  config.current_tenant_method = :current_tenant_id
  config.tenant_model = 'Account'

  # Redis for unique visitor tracking (optional)
  config.redis_enabled = true
  config.redis_namespace = 'content_signals'

  # MaxMind GeoLite2 database path
  config.maxmind_db_path = Rails.root.join('db', 'GeoLite2-City.mmdb')

  # Tracking preferences
  config.track_bots = false
  config.track_admins = false
end
```

### Analytics Queries

Access rich analytics data through PageView scopes:

```ruby
# Get page views for a specific page
page = Page.find(1)
page_views = ContentSignals::PageView.where(trackable: page)

# Time-based queries
page_views.today
page_views.yesterday
page_views.this_week
page_views.last_30_days
page_views.this_month
page_views.this_year

# Device filtering
page_views.mobile
page_views.desktop
page_views.tablet

# Location filtering
page_views.from_country('US')
page_views.from_city('New York')

# Platform filtering
page_views.from_website      # Regular web browsers
page_views.from_hybrid_app   # Mobile app WebViews
page_views.from_native_app   # Native mobile apps

# User filtering
page_views.authenticated  # Logged-in users
page_views.anonymous      # Anonymous visitors

# Analytics aggregations
page_views.unique_count              # Unique visitors
page_views.top_countries(10)         # Top 10 countries
page_views.top_cities(10)            # Top 10 cities
page_views.device_breakdown          # Device type distribution
page_views.browser_breakdown         # Browser distribution
page_views.location_heatmap          # Lat/lng data for maps

# Growth rate
page_views.growth_rate(:this_week, :last_week)  # Weekly growth %
```

### Example: Analytics Dashboard

```ruby
class AnalyticsController < ApplicationController
  def show
    @page = Page.find(params[:id])
    @views = ContentSignals::PageView.where(trackable: @page).last_30_days

    @stats = {
      total_views: @views.count,
      unique_visitors: @views.unique_count,
      top_countries: @views.top_countries(5),
      top_cities: @views.top_cities(5),
      device_breakdown: @views.device_breakdown,
      growth_rate: @views.growth_rate(:this_week, :last_week)
    }
  end
end
```

### Custom Trackable Finder

By default, the concern looks for `@page`, `@post`, `@article`, `@profile`, `@event`, or `@trackable`. To customize:

```ruby
class ArticlesController < ApplicationController
  include ContentSignals::TrackablePageViews

  def show
    @my_article = Article.find(params[:id])
  end

  private

  def find_trackable_for_tracking
    @my_article
  end
end
```

### Skip Tracking Conditions

Override to add custom skip conditions:

```ruby
class PagesController < ApplicationController
  include ContentSignals::TrackablePageViews

  private

  def should_skip_tracking?
    super || draft_mode? || current_user&.internal?
  end

  def draft_mode?
    params[:draft].present?
  end
end
```

### Manual Tracking

Track views programmatically without the controller concern:

```ruby
ContentSignals::PageViewTracker.track(
  trackable: @page,
  user: current_user,
  request: request
)
```

### Multi-Tenant Setup

For multi-tenant applications:

```ruby
# config/initializers/content_signals.rb
ContentSignals.configure do |config|
  config.multitenancy = true
  config.current_tenant_method = :current_account_id
end

# In your ApplicationController
class ApplicationController < ActionController::Base
  def current_account_id
    Current.account_id  # or however you track tenant context
  end
end
```

All PageView queries will automatically scope to the current tenant.

### Hybrid Mobile App Support

Track views from mobile apps (Capacitor, Cordova, React Native, Flutter):

#### Send custom headers from your app:

```javascript
// In your mobile app
fetch('https://yoursite.com/pages/1', {
  headers: {
    'X-App-Platform': 'capacitor',
    'X-App-Version': '1.2.3',
    'X-Device-ID': 'unique-device-uuid'
  }
});
```

#### Or use URL parameters:

```
https://yoursite.com/pages/1?app_platform=capacitor&device_id=abc123&app_version=1.2.3
```

Views from mobile apps will be automatically detected and tracked with `app_platform` and `device_id`.

### Geolocation Setup

1. **Sign up for MaxMind GeoLite2** (free): https://www.maxmind.com/en/geolite2/signup
2. **Download GeoLite2-City.mmdb** database
3. **Place in:** `db/GeoLite2-City.mmdb`
4. **Configure path** in initializer (shown above)

The gem will automatically enrich page views with:
- Country (code and name)
- City
- Region/State
- Latitude/Longitude

### PageView Model

Access individual page view records:

```ruby
view = ContentSignals::PageView.last

view.trackable           # => #<Page id: 1>
view.user                # => #<User id: 5> (if authenticated)
view.visitor_id          # => "user_5" or "device_abc123" or "anon_1a2b3c"
view.country_name        # => "United States"
view.city                # => "New York"
view.device_type         # => "mobile"
view.browser             # => "Chrome"
view.os                  # => "iOS"
view.app_platform        # => "capacitor" (if from mobile app)
view.viewed_at           # => 2026-01-06 10:30:00 UTC

# Helper methods
view.authenticated?      # => true if user present
view.anonymous?          # => true if no user
view.mobile_device?      # => true if mobile
view.desktop_device?     # => true if desktop
view.hybrid_app?         # => true if from mobile app
view.web_browser?        # => true if from web browser
```

## Advanced Usage

### Custom User Method

If you use a different method name for current user:

```ruby
class PagesController < ApplicationController
  include ContentSignals::TrackablePageViews

  private

  def current_user_for_tracking
    current_person  # or whatever your method is called
  end
end
```

### Background Job Queue

By default, tracking jobs use the `default` queue. To customize:

```ruby
# config/initializers/content_signals.rb
ContentSignals::TrackPageViewJob.queue_as :analytics
```

### Export Analytics Data

```ruby
# Export to CSV
require 'csv'

CSV.generate(headers: true) do |csv|
  csv << ['Date', 'Country', 'City', 'Device', 'Browser']

  ContentSignals::PageView.where(trackable: @page).find_each do |view|
    csv << [
      view.viewed_at.to_date,
      view.country_name,
      view.city,
      view.device_type,
      view.browser
    ]
  end
end
```

## Requirements

- Rails >= 7.0
- Ruby >= 3.0
- ActiveJob (for background processing)
- Redis (optional, for unique visitor tracking)

### Optional Dependencies

```ruby
# Gemfile
gem 'maxminddb'  # For IP geolocation
gem 'browser'    # For device/browser detection
gem 'redis'      # For unique visitor tracking
```

## Performance

- **Fast**: Counter increments are synchronous (< 1ms)
- **Non-blocking**: Detailed tracking happens in background jobs
- **Scalable**: Uses counter caching and database indexes
- **Efficient**: Redis-based unique visitor deduplication (optional)

## Testing

In your test environment, you may want to disable tracking:

```ruby
# config/environments/test.rb
config.after_initialize do
  ContentSignals.configure do |config|
    config.track_bots = true  # Allow test requests
  end
end
```

Or stub the tracker in specs:

```ruby
allow(ContentSignals::PageViewTracker).to receive(:track)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/content_signals. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/content_signals/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ContentSignals project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/content_signals/blob/main/CODE_OF_CONDUCT.md).
