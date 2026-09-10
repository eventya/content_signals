## [Unreleased]

## [0.1.17]

### Fixed

- A request from a Hotwire Native app is recognised by the name every one of them sends. Detection matched only `Turbo Native`, which the webview appends but the app's own HTTP client does not send at all, so those requests were read by device instead: an Android one as a phone, an iOS one as a **desktop**.

## [0.1.16]

### Fixed

- A page view from a mobile app is no longer thrown away. `PageView` validated `device_type` as `desktop/mobile/tablet` while `scope :app` queried for `hybrid_app`, so the value the detector produced for an app could never be stored — and `TrackPageViewJob` rescues the failure, so the view vanished with only a log line. `app_platform` had the same mismatch against every value `detect_platform_from_ua` returns.

## [0.1.0] - 2026-01-06

- Initial release
