# frozen_string_literal: true

module ContentSignals
  class AggregateAnalyticsJob < ActiveJob::Base
    queue_as :default

    # Aggregates raw page_views for a given date into analytics_daily_stats.
    # Designed to be run hourly — today's entry is upserted on each run.
    # Pass date: as a Date or String (default: aggregates yesterday + today).
    def perform(date: nil)
      if date
        aggregate_for_date(date.to_date)
      else
        aggregate_for_date(Date.yesterday)
        aggregate_for_date(Date.today)
      end
    end

    private

    def aggregate_for_date(date)
      day_scope = PageView.where(viewed_at: date.beginning_of_day..date.end_of_day)
      return if day_scope.none?

      groups = day_scope
        .group(:tenant_id, :trackable_type, :trackable_id)
        .count

      groups.each_key do |(tenant_id, trackable_type, trackable_id)|
        scope = day_scope.where(
          tenant_id: tenant_id,
          trackable_type: trackable_type,
          trackable_id: trackable_id
        )

        row = {
          tenant_id:,
          trackable_type:,
          trackable_id:,
          date:,
          total_views:       scope.count,
          unique_visitors:   scope.distinct.count(:visitor_id),
          app_views:         scope.where.not(app_platform: [ nil, "" ]).count,
          device_breakdown:  breakdown(scope, :device_type),
          os_breakdown:      breakdown(scope, :os),
          browser_breakdown: breakdown(scope, :browser),
          country_breakdown: breakdown(scope, :country_name),
          city_breakdown:    breakdown(scope, :city),
          referrer_breakdown: referrer_breakdown(scope),
          locale_breakdown:  breakdown(scope, :locale),
          hourly_breakdown:  hourly_breakdown(scope),
          updated_at:        Time.current
        }

        AnalyticsDailyStat.upsert(
          row,
          unique_by: %i[tenant_id trackable_type trackable_id date]
        )
      end
    end

    def breakdown(scope, column)
      scope.where.not(column => [ nil, "" ])
           .group(column)
           .count
           .to_json
    end

    def referrer_breakdown(scope)
      scope.where.not(referrer: [ nil, "" ])
           .group(:referrer)
           .count
           .each_with_object({}) { |(url, count), h|
             domain = extract_domain(url)
             h[domain] = (h[domain] || 0) + count
           }
           .to_json
    end

    def hourly_breakdown(scope)
      scope.group("CAST(EXTRACT(HOUR FROM viewed_at) AS INTEGER)")
           .count
           .transform_keys(&:to_s)
           .to_json
    end

    def extract_domain(url)
      URI.parse(url).host&.sub(/\Awww\./, "") || url
    rescue URI::InvalidURIError
      url.to_s.truncate(60)
    end
  end
end
