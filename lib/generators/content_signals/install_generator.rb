# frozen_string_literal: true

require "rails/generators"
require "rails/generators/migration"

module ContentSignals
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Creates ContentSignals migration, initializer, and recurring job schedule"

      def self.next_migration_number(path)
        next_migration_number = current_migration_number(path) + 1
        ActiveRecord::Migration.next_migration_number(next_migration_number)
      end

      def copy_migration
        migration_template "create_content_signals_page_views.rb.erb",
                           "db/migrate/create_content_signals_page_views.rb",
                           migration_version: migration_version
      end

      def copy_initializer
        template "content_signals.rb.erb", "config/initializers/content_signals.rb"
      end

      def inject_recurring_job
        recurring_yml = "config/recurring.yml"

        if File.exist?(File.join(destination_root, recurring_yml))
          content = File.read(File.join(destination_root, recurring_yml))

          if content.include?("ContentSignals::UpdateGeoipDatabaseJob")
            say_status :skip, "recurring.yml already contains ContentSignals::UpdateGeoipDatabaseJob", :yellow
          else
            append_to_file recurring_yml, <<~YAML

              # ContentSignals — refresh GeoLite2-City database weekly (MaxMind updates Tuesdays)
              content_signals_update_geoip_database:
                class: ContentSignals::UpdateGeoipDatabaseJob
                schedule: every week at 4am
            YAML
            say_status :append, recurring_yml, :green
          end
        else
          create_file recurring_yml, <<~YAML
            # ContentSignals — refresh GeoLite2-City database weekly (MaxMind updates Tuesdays)
            content_signals_update_geoip_database:
              class: ContentSignals::UpdateGeoipDatabaseJob
              schedule: every week at 4am
          YAML
        end
      end

      def show_readme
        readme "README" if behavior == :invoke
      end

      private

      def migration_version
        "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
      end
    end
  end
end
