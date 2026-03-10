# frozen_string_literal: true

module ContentSignals
  class AnalyticsDailyStat < ActiveRecord::Base
    self.table_name = "content_signals_analytics_daily_stats"

    validates :trackable_type, :trackable_id, :date, presence: true

    # JSON breakdown columns — stored as text, parsed on read
    BREAKDOWN_COLUMNS = %i[
      device_breakdown
      os_breakdown
      browser_breakdown
      country_breakdown
      city_breakdown
      referrer_breakdown
      locale_breakdown
      hourly_breakdown
    ].freeze

    BREAKDOWN_COLUMNS.each do |col|
      define_method(col) do
        raw = super()
        return {} if raw.blank?
        JSON.parse(raw)
      rescue JSON::ParserError
        {}
      end

      define_method(:"#{col}=") do |value|
        super(value.is_a?(Hash) ? value.to_json : value)
      end
    end

    scope :for_tenant,     ->(id)   { where(tenant_id: id) }
    scope :for_trackable,  ->(type, ids) { where(trackable_type: type, trackable_id: ids) }
    scope :in_range,       ->(range) { where(date: range) }
  end
end
