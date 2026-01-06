# frozen_string_literal: true

require_relative "lib/content_signals/version"

Gem::Specification.new do |spec|
  spec.name = "content_signals"
  spec.version = ContentSignals::VERSION
  spec.authors = ["Ionuț Munteanu Alexandru"]
  spec.email = ["ionut.munteanu@eventya.net"]

  spec.summary = "Content analytics for Rails - track page views, demographics, and engagement metrics"
  spec.description = "Track views, demographics, device types, and engagement signals for any Rails model. Polymorphic, multi-tenant ready, with hybrid mobile app support."
  spec.homepage = "https://github.com/imunteanu/content_signals"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/imunteanu/content_signals"
  spec.metadata["changelog_uri"] = "https://github.com/imunteanu/content_signals/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/imunteanu/content_signals/issues"
  spec.metadata["documentation_uri"] = "https://github.com/imunteanu/content_signals#readme"

  # Specify which files should be added to the gem when it is released.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "rails", ">= 7.0"
  spec.add_dependency "maxmind-geoip2", "~> 1.1"  # IP geolocation (correct gem name)
  spec.add_dependency "browser", "~> 5.0"         # Device/browser detection

  # Development dependencies
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "sqlite3", ">= 2.1"
  spec.add_development_dependency "pg", "~> 1.1"
end
