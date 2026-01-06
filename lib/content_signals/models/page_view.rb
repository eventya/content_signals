# frozen_string_literal: true

module ContentSignals
  class PageView < ActiveRecord::Base
    self.table_name = "content_signals_page_views"

    # Associations
    belongs_to :trackable, polymorphic: true, counter_cache: :page_views_count
    belongs_to :tenant, optional: true if ContentSignals.configuration.multitenancy?
    belongs_to :user, optional: true

    # Validations
    validates :trackable_type, :trackable_id, :visitor_id, :viewed_at, presence: true
    validates :country_code, length: { maximum: 2 }, allow_nil: true
    validates :device_type, inclusion: { in: %w[desktop mobile tablet] }, allow_nil: true
    validates :app_platform, inclusion: { in: %w[hybrid native] }, allow_nil: true

    # Default scope for tenant isolation (when multitenancy is enabled)
    if ContentSignals.configuration.multitenancy?
      default_scope -> { where(tenant_id: current_tenant_id) }

      def self.current_tenant_id
        return nil unless ContentSignals.configuration.multitenancy?

        method_name = ContentSignals.configuration.current_tenant_method
        return nil unless method_name

        # Try to get tenant_id from Current, controller, or thread
        if defined?(Current) && Current.respond_to?(method_name)
          Current.send(method_name)
        elsif Thread.current[method_name]
          Thread.current[method_name]
        end
      end
    end

    # Time period scopes
    scope :today, -> { where("viewed_at >= ?", Time.current.beginning_of_day) }
    scope :yesterday, -> { where(viewed_at: 1.day.ago.all_day) }
    scope :this_week, -> { where("viewed_at >= ?", Time.current.beginning_of_week) }
    scope :last_week, -> { where(viewed_at: 1.week.ago.beginning_of_week..1.week.ago.end_of_week) }
    scope :this_month, -> { where("viewed_at >= ?", Time.current.beginning_of_month) }
    scope :last_month, -> { where(viewed_at: 1.month.ago.beginning_of_month..1.month.ago.end_of_month) }
    scope :last_30_days, -> { where("viewed_at >= ?", 30.days.ago) }
    scope :last_90_days, -> { where("viewed_at >= ?", 90.days.ago) }
    scope :this_year, -> { where("viewed_at >= ?", Time.current.beginning_of_year) }

    # Device scopes
    scope :mobile, -> { where(device_type: "mobile") }
    scope :desktop, -> { where(device_type: "desktop") }
    scope :tablet, -> { where(device_type: "tablet") }
    scope :app, -> { where(device_type: "hybrid_app") }
    scope :web, -> { where(device_type: %w[desktop mobile tablet]) }

    # Platform scopes
    scope :from_hybrid_app, -> { where(app_platform: "hybrid") }
    scope :from_native_app, -> { where.not(app_platform: "native") }
    scope :from_website, -> { where(app_platform: nil) }

    # Location scopes
    scope :from_country, ->(country_code) { where(country_code: country_code.to_s.upcase) }
    scope :from_city, ->(city) { where(city: city) }
    scope :from_region, ->(region) { where(region: region) }

    # User scopes
    scope :authenticated, -> { where.not(user_id: nil) }
    scope :anonymous, -> { where(user_id: nil) }

    # Ordering scopes
    scope :recent, -> { order(viewed_at: :desc) }
    scope :oldest, -> { order(viewed_at: :asc) }

    # Analytics methods
    class << self
      def unique_count(period = :all_time)
        scope = period == :all_time ? self : send(period)
        scope.distinct.count(:visitor_id)
      end

      def top_countries(limit = 10)
        where.not(country_name: nil)
          .group(:country_code, :country_name)
          .order("count_id DESC")
          .limit(limit)
          .count(:id)
      end

      def top_cities(limit = 10)
        where.not(city: nil)
          .group(:city, :country_name)
          .order("count_id DESC")
          .limit(limit)
          .count(:id)
      end

      def top_regions(limit = 10)
        where.not(region: nil)
          .group(:region, :country_name)
          .order("count_id DESC")
          .limit(limit)
          .count(:id)
      end

      def device_breakdown
        group(:device_type)
          .order("count_id DESC")
          .count(:id)
      end

      def browser_breakdown(limit = 10)
        where.not(browser: nil)
          .group(:browser)
          .order("count_id DESC")
          .limit(limit)
          .count(:id)
      end

      def os_breakdown(limit = 10)
        where.not(os: nil)
          .group(:os)
          .order("count_id DESC")
          .limit(limit)
          .count(:id)
      end

      def platform_breakdown
        group(:app_platform)
          .order("count_id DESC")
          .count(:id)
      end

      def hourly_distribution
        group("EXTRACT(HOUR FROM viewed_at)::integer")
          .order("EXTRACT(HOUR FROM viewed_at)::integer")
          .count(:id)
      end

      def daily_distribution(days = 30)
        where("viewed_at >= ?", days.days.ago)
          .group("DATE(viewed_at)")
          .order("DATE(viewed_at)")
          .count(:id)
      end

      def weekly_distribution(weeks = 12)
        where("viewed_at >= ?", weeks.weeks.ago)
          .group("strftime('%Y-%W', viewed_at)")
          .order("strftime('%Y-%W', viewed_at)")
          .count(:id)
      end

      def monthly_distribution(months = 12)
        where("viewed_at >= ?", months.months.ago)
          .group("strftime('%Y-%m', viewed_at)")
          .order("strftime('%Y-%m', viewed_at)")
          .count(:id)
      end

      # For map visualization - returns array of [lat, lng, count]
      def location_heatmap
        where.not(latitude: nil, longitude: nil)
          .group(:latitude, :longitude)
          .count(:id)
          .map { |(lat, lng), count| { lat: lat.to_f, lng: lng.to_f, count: count } }
      end

      # Referrer analysis
      def top_referrers(limit = 10)
        where.not(referrer: nil)
          .where.not(referrer: "")
          .group(:referrer)
          .order("count_id DESC")
          .limit(limit)
          .count(:id)
      end

      # Growth metrics
      def growth_rate(period = :last_30_days)
        current_period = send(period).count

        previous_period_start = case period
        when :today then 1.day.ago.beginning_of_day
        when :this_week then 1.week.ago.beginning_of_week
        when :this_month then 1.month.ago.beginning_of_month
        when :last_30_days then 60.days.ago
        else 1.day.ago
        end

        previous_period_end = case period
        when :today then 1.day.ago.end_of_day
        when :this_week then 1.week.ago.end_of_week
        when :this_month then 1.month.ago.end_of_month
        when :last_30_days then 30.days.ago
        else Time.current
        end

        previous_period = where(viewed_at: previous_period_start..previous_period_end).count

        return 0 if previous_period.zero?
        ((current_period - previous_period).to_f / previous_period * 100).round(2)
      end
    end

    # Instance methods
    def web_browser?
      app_platform.nil?
    end

    def hybrid_app?
      app_platform.present?
    end

    def mobile_device?
      device_type.in?(%w[mobile tablet])
    end

    def desktop_device?
      device_type == "desktop"
    end

    def authenticated?
      user_id.present?
    end

    def anonymous?
      user_id.nil?
    end
  end
end
