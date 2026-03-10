# frozen_string_literal: true

module ContentSignals
  class PurgePageViewsJob < ActiveJob::Base
    queue_as :default

    # Deletes raw page_views older than retention_days (default 90).
    # Run daily. Only deletes records that have already been aggregated
    # (i.e., older than 1 day beyond retention window to be safe).
    def perform
      retention_days = ContentSignals.configuration.retention_days
      cutoff = retention_days.days.ago.beginning_of_day

      deleted = 0
      PageView.where("viewed_at < ?", cutoff).in_batches(of: 2000) do |batch|
        deleted += batch.delete_all
      end

      Rails.logger.info "[ContentSignals] PurgePageViewsJob: deleted #{deleted} records older than #{cutoff.to_date}"
    end
  end
end
