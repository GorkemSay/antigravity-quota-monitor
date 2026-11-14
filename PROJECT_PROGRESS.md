# Project Progress — Antigravity Quota Monitor

## Project Overview

**Antigravity Quota Monitor** is a native macOS SwiftUI menu bar utility that detects the currently selected Antigravity AI model in Xcode via Apple's Accessibility APIs and displays real remaining usage quota retrieved via the official Antigravity CLI (`agy`).

- **Repository:** `https://github.com/GorkemSay/antigravity-quota-monitor` (Public)
- **License:** MIT (`LICENSE`)
- **Platform:** macOS 15.0+ (developed on macOS 26.7.2, Xcode 27.2, Swift 6.4.2)
- **Architecture:** Modular SwiftUI (`MenuBarExtra`) + isolated domain services (`XcodeModelDetector`, `AntigravityQuotaProvider`, `ModelQuotaMapper`, `QuotaManager`)

---

## Current Milestone

**Milestone 4 — Model and Quota Integration** (Completed)

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
- Created `AntigravityQuotaMonitor/Services/ModelQuotaMapper.swift` mapping detected models to quota groups via exact group names, `group.description` model lists, and model-family fallbacks (ensuring `Gemini 4 Argon` maps separately from `Gemini Models` and unknown models return `.unmatched` instead of guessing).
- Created `AntigravityQuotaMonitor/Services/QuotaManager.swift` (`@MainActor @Observable`) orchestrating `ModelDetecting` and `QuotaFetching`, producing compact menu bar strings (`"H 90%"`, `"A 99%"`), supporting lightweight active-model re-checks (`refreshActiveModelOnly()`), and preserving stale snapshots transparently with `isStale` and `lastError` when subsequent refreshes fail or exceed `staleThreshold`.
- Marked `DetectedModel`, `ModelDetectionResult`, `AccessibilityTreeReading`, `LiveAccessibilityTreeReader`, `XcodeModelDetector`, `ModelDetecting`, and `QuotaFetching` explicitly `nonisolated` for zero-warning Swift 6 strict concurrency compliance.
- Added `AntigravityQuotaMonitorTests/ModelQuotaMapperTests.swift` and `AntigravityQuotaMonitorTests/QuotaManagerTests.swift` (11 new tests covering mapping, unknown models, model switching, stale preservation, and error states).

---

## Technical Decisions

1. **Three-Tier Model-to-Group Matching:** `ModelQuotaMapper` checks (1) exact normalized group name (`Gemini 4 Argon`), (2) comma-separated model names in `group.description`, and (3) family fallbacks (`argon` vs `hydrogen`/`flash`/`gemini` vs `claude`/`opus`/`sonnet`/`gpt`), returning `.unmatched` for unknown models rather than displaying misleading percentages.
2. **Stale Snapshot Preservation:** When `QuotaManager.refreshAll()` fails after an earlier successful fetch, `snapshot` and `lastSuccessfulUpdate` are preserved, `lastError` records the failure, and `isStale` becomes `true`.
3. **Explicit `nonisolated` Boundaries:** Because the project enables `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, pure domain types and background worker protocols are explicitly marked `nonisolated` so Swift 6 concurrency checks pass with zero warnings.

---

## Testing Results

- `xcodebuild test -project AntigravityQuotaMonitor.xcodeproj -scheme AntigravityQuotaMonitor -destination 'platform=macOS' -only-testing:AntigravityQuotaMonitorTests`: **29 passed, 0 failed** (7 suites), zero Swift compiler warnings.

---

## Known Issues

- `QuotaManager` is not yet wired into `AntigravityQuotaMonitorApp` / `MenuBarContentView` (planned for Milestone 5).

---

## Next Steps

**Milestone 5 — Native Menu Bar Interface**
- Wire `QuotaManager` into `AntigravityQuotaMonitorApp` and `MenuBarContentView`.
- Display `"atom"` SF Symbol + active model abbreviation & lowest remaining quota percentage in the macOS menu bar (e.g., `H 90%`, `A 99%`, or explicit permission/loading/stale indicators).
- Build the expanded popover showing active model & group breakdown, 5-hour / weekly progress bars, local-timezone reset times, other quota groups, last updated timestamp, refresh button, and quit button.

---

## Git Information

- **Repository:** `https://github.com/GorkemSay/antigravity-quota-monitor`
- **Branch:** `main`
- **Latest Commit:** Updated upon Milestone 4 completion.
