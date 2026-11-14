# Project Progress — Antigravity Quota Monitor

## Project Overview

**Antigravity Quota Monitor** is a native macOS SwiftUI menu bar utility that detects the currently selected Antigravity AI model in Xcode via Apple's Accessibility APIs and displays real remaining usage quota retrieved via the official Antigravity CLI (`agy`).

- **Repository:** `https://github.com/GorkemSay/antigravity-quota-monitor` (Public)
- **License:** MIT (`LICENSE`)
- **Platform:** macOS 15.0+ (developed on macOS 26.7.2, Xcode 27.2, Swift 6.4.2)
- **Architecture:** Modular SwiftUI (`MenuBarExtra`) + isolated domain services (`XcodeModelDetector`, `AntigravityQuotaProvider`, `ModelQuotaMapper`, `QuotaManager`)

---

## Current Milestone

**Milestone 3 — CLI Quota Provider** (Completed)

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
- Inspected live `agy -p "/usage" --output-format json` payload structure (including optional bucket `description` when remaining quota is `100%`, `remaining_fraction`, and ISO-8601 `reset_time`).
- Created `AntigravityQuotaMonitor/Models/QuotaModels.swift` (`QuotaBucket`, `QuotaGroup`, `QuotaSnapshot`, `QuotaProviderError`).
- Created `AntigravityQuotaMonitor/Services/AntigravityQuotaProvider.swift`:
  - `SystemCLIProcessRunner` using `Foundation.Process`, null stdin, concurrent stdout/stderr reading, timeout termination, and `OSAllocatedUnfairLock` (zero Swift 6 concurrency warnings).
  - `QuotaCLIResponseParser` with quote-aware, escape-aware balanced `{...}` JSON object extraction supporting leading logs and trailing Markdown.
  - `AntigravityQuotaProvider` actor with configurable/default `agy` discovery (`$HOME/.local/bin/agy`, Homebrew/system paths, `PATH`) and in-flight task coalescing to prevent overlapping CLI runs.
- Created `AntigravityQuotaMonitorTests/AntigravityQuotaProviderTests.swift` with 7 unit tests covering parsing, wrapped JSON extraction, error states, path resolution, timeouts/exit codes, and overlap coalescing.

---

## Technical Decisions

1. **Actor-Level Task Coalescing:** `AntigravityQuotaProvider` stores `inFlightTask` so concurrent refresh requests share one `Process` execution rather than launching overlapping `agy` processes.
2. **Optional Bucket Descriptions:** Live `agy` output omits `buckets[].description` when a bucket is at `100%` (`remaining_fraction: 1`), so `description` is modeled as `String?`.
3. **Swift 6 Concurrency Safety:** Used `OSAllocatedUnfairLock` inside `SystemCLIProcessRunner` and `nonisolated` model/parser types so `AntigravityQuotaProvider` compiles cleanly under Swift 6 strict concurrency checking despite `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
4. **No Default Raw Output Logging:** Raw CLI stdout/stderr is never logged or persisted by default.

---

## Testing Results

- `xcodebuild test -project AntigravityQuotaMonitor.xcodeproj -scheme AntigravityQuotaMonitor -destination 'platform=macOS' -only-testing:AntigravityQuotaMonitorTests`: **18 passed, 0 failed** (5 suites).
- Live CLI integration verification of `AntigravityQuotaProvider().fetchQuota()` against `/Users/gorkemsay/.local/bin/agy`: **Succeeded**, decoded 3 quota groups (`Gemini Models`, `Claude and GPT models`, `Gemini 4 Argon`) with zero compiler warnings.

---

## Known Issues

- Model-to-quota group mapping (`ModelQuotaMapper`) and UI wiring (`QuotaManager`) are not yet connected (scheduled for Milestones 4–5).

---

## Next Steps

**Milestone 4 — Model and Quota Integration**
- Implement `ModelQuotaMapper` to map detected Xcode models (and `group.description` model lists) to quota groups cleanly and handle unknown models explicitly.
- Implement `QuotaManager` (`@MainActor` observable coordinator) combining `XcodeModelDetector` and `AntigravityQuotaProvider`, computing lowest remaining percentage for the active model group, and preserving stale snapshot visibility on refresh errors.
- Add unit tests for all model/group mapping and error/stale scenarios.

---

## Git Information

- **Repository:** `https://github.com/GorkemSay/antigravity-quota-monitor`
- **Branch:** `main`
- **Latest Commit:** Updated upon Milestone 3 completion.
