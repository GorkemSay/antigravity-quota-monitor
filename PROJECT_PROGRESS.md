# Project Progress — Antigravity Quota Monitor

## Project Overview

**Antigravity Quota Monitor** is a native macOS SwiftUI menu bar utility that detects the currently selected Antigravity AI model in Xcode via Apple's Accessibility APIs and displays real remaining usage quota retrieved via the official Antigravity CLI (`agy`).

- **Repository:** `https://github.com/GorkemSay/antigravity-quota-monitor` (Public)
- **License:** MIT (`LICENSE`)
- **Platform:** macOS 15.0+ (developed on macOS 26.7.2, Xcode 27.2, Swift 6.4.2)
- **Architecture:** Modular SwiftUI (`MenuBarExtra`) + isolated domain services (`XcodeModelDetector`, `AntigravityQuotaProvider`, `ModelQuotaMapper`, `QuotaManager`)

---

## Current Milestone

**Milestone 5 — Native Menu Bar Interface** (Completed)

---

## Completed Tasks

### Milestone 0 — Environment and Feasibility Review
- Verified Swift `6.4.2`, Xcode `27.2`, macOS `26.7.2` (`arm64`), Git `2.54.0`, and GitHub CLI `2.103.2` (`GorkemSay` authenticated).
- Verified Antigravity CLI `/Users/gorkemsay/.local/bin/agy` (`1.5.9`).
- Reviewed working Accessibility prototype `~/Downloads/XcodeActiveModelProbe_fixed.swift`.

### Milestone 1 — Xcode Project and GitHub Repository
- Created native macOS targets `AntigravityQuotaMonitor`, `AntigravityQuotaMonitorTests` (Swift Testing), and `AntigravityQuotaMonitorUITests`.
- Configured macOS-only build settings (`MACOSX_DEPLOYMENT_TARGET = 15.0`, `ENABLE_APP_SANDBOX = NO`, `INFOPLIST_KEY_LSUIElement = YES`).
- Implemented minimal `MenuBarExtra` entry point (`atom` SF Symbol), initialized Git, pushed to `GorkemSay/antigravity-quota-monitor`, renamed `AntigravityQuotaMonitor.xcodeproj`, removed template `MyApp`, and added MIT `LICENSE`.

### Milestone 2 — Active Model Detection
- Implemented `DetectedModel` parser and `XcodeModelDetector` with `LiveAccessibilityTreeReader` and `AccessibilityTreeReading` abstraction.
- Verified live model detection (`Gemini 4 Hydrogen (High)`, `H`) inside `AntigravityQuotaMonitor.app`.

### Milestone 3 — CLI Quota Provider
- Implemented `QuotaModels.swift` and `AntigravityQuotaProvider.swift` (`SystemCLIProcessRunner`, `QuotaCLIResponseParser`, task coalescing, and executable path discovery).
- Verified live CLI retrieval against `/Users/gorkemsay/.local/bin/agy`.

### Milestone 4 — Model and Quota Integration
- Implemented `ModelQuotaMapper.swift` and `QuotaManager.swift` (`@MainActor @Observable`) with stale-snapshot preservation and zero-warning Swift 6 concurrency isolation.

### Milestone 5 — Native Menu Bar Interface
- Created `AntigravityQuotaMonitor/Utilities/QuotaFormatting.swift` for local-timezone reset timestamp formatting (`Today, HH:mm`, `Tomorrow, HH:mm`, `MMM d, HH:mm`), relative countdowns, last updated formatting, and remaining quota tint colors.
- Created `AntigravityQuotaMonitor/Views/QuotaBucketRowView.swift` displaying bucket labels, percentages, linear progress bars, and local reset timestamps.
- Updated `AntigravityQuotaMonitor/App/AntigravityQuotaMonitorApp.swift` to host `QuotaManager`, trigger startup refresh in `init()`, and render the `"atom"` SF Symbol + active model abbreviation & lowest remaining quota percentage (e.g., `H 90%`, `A 99%`) in the macOS menu bar.
- Updated `AntigravityQuotaMonitor/Views/MenuBarContentView.swift` with active model & group breakdown, other quota groups, stale/error banners, Accessibility permission prompt, last updated footer, `Refresh` (`Cmd + R`), and `Quit` (`Cmd + Q`).
- Added `AntigravityQuotaMonitorTests/QuotaFormattingTests.swift` covering same-day, multi-day, and last-updated formatting.

---

## Technical Decisions

1. **Startup Refresh in `App.init()`:** `MenuBarExtra` popover content is lazily mounted only when clicked, so initial `QuotaManager.refreshAll()` is kicked off from `AntigravityQuotaMonitorApp.init()` to populate the menu bar indicator immediately at launch.
2. **Popover Re-open Model Sync:** Opening the popover calls `refreshActiveModelOnly()` (fast Accessibility check without spawning `agy`) so switching models in Xcode updates the UI immediately on popover open.
3. **Graceful Degradation:** Even if Xcode is closed or model detection fails, previously fetched quota groups remain visible inside the popover, and errors preserve stale snapshots with an explicit `Stale` badge.

---

## Testing Results

- `xcodebuild test -project AntigravityQuotaMonitor.xcodeproj -scheme AntigravityQuotaMonitor -destination 'platform=macOS' -only-testing:AntigravityQuotaMonitorTests`: **32 passed, 0 failed** (8 suites), zero Swift compiler warnings.

---

## Known Issues

- Automatic periodic background polling, user-configurable refresh interval / CLI path Settings, and optional Launch at Login (`ServiceManagement`) are not yet implemented (planned for Milestone 6).

---

## Next Steps

**Milestone 6 — Background Updates and Preferences**
- Add periodic refresh timer (default 3 minutes, configurable 2–5 minutes) plus lightweight active-model polling or refresh-on-open behavior.
- Add minimal Settings UI (popover subview or native macOS Settings window) for refresh interval, optional custom `agy` path (wired into `AntigravityQuotaProvider`), and optional Launch at Login (`SMAppService.mainApp`).
- Add unit tests for timer scheduling, preference persistence, and settings validation.

---

## Git Information

- **Repository:** `https://github.com/GorkemSay/antigravity-quota-monitor`
- **Branch:** `main`
- **Latest Commit:** Updated upon Milestone 5 completion.
