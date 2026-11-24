# Project Progress — Antigravity Quota Monitor

## Project Overview

**Antigravity Quota Monitor** is a native macOS SwiftUI menu bar utility that detects the currently selected Antigravity AI model in Xcode via Apple's Accessibility APIs and displays real remaining usage quota retrieved via the official Antigravity CLI (`agy`).

- **Repository:** `https://github.com/GorkemSay/antigravity-quota-monitor` (Public)
- **License:** MIT (`LICENSE`)
- **Platform:** macOS 15.0+ (verified on macOS 26.7.2, Xcode 27.2, Swift 6.4.2)
- **Architecture:** Modular SwiftUI (`MenuBarExtra`) + isolated domain services (`XcodeModelDetector`, `AntigravityQuotaProvider`, `ModelQuotaMapper`, `QuotaManager`, `PreferencesStore`, `AppUpdateManager`)

---

## Current Milestone

**Milestone 10 — Unified Gemini Quota Pool (Argon Merge) & Orchestrator Claude Opus 5.5 Support** (Completed)

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
- Implemented `QuotaFormatting.swift`, `QuotaBucketRowView.swift`, live menu bar label (`H 90%`, `A 99%`), and expanded popover UI in `MenuBarContentView.swift`.

### Milestone 6 — Background Updates and Preferences
- Implemented `PreferencesStore.swift`, `SettingsView.swift`, background quota & model polling in `QuotaManager.swift`, and `SMAppService.mainApp` Launch at Login support.

### Milestone 7 — Testing, Polish, and Release Preparation
- Hardened `SystemCLIProcessRunner` to explicitly close stdout/stderr `FileHandle` descriptors after EOF and on launch failure to eliminate file-descriptor leakage.
- Updated `AntigravityQuotaMonitorUITests/AntigravityQuotaMonitorUITests.swift` with `testMenuBarAppLaunchesAndRelaunchesCleanly()` verifying agent launch, termination, and clean relaunch.
- Generated full macOS `AppIcon.appiconset` (`16x16` through `512x512@2x`) matching the menu bar `"atom"` emblem.
- Updated `PRODUCT_NAME` to `"Antigravity Quota Monitor"` (while preserving `PRODUCT_MODULE_NAME = "AntigravityQuotaMonitor"`) so the bundle installs cleanly as `/Applications/Antigravity Quota Monitor.app`.
- Updated `QuotaBucketRowView` with a pure SwiftUI `QuotaLinearProgressStyle` and `MenuBarContentView` gear button with `.buttonStyle(.plain)`, and re-rendered clean Retina screenshots (`docs/screenshots/menubar-popover.png` and `docs/screenshots/settings-popover.png`).
- Polished `README.md` for end users (removed internal roadmap, added clear Download & Build installation instructions).
- Audited all source files under `AntigravityQuotaMonitor/` — zero raw logging or credential handling.
- Verified full unit + UI test suite and `Release` build, and published GitHub Release `v1.0.0`.

### Milestone 8 — New Gemini 4 Models & Orchestrator Support
- Analyzed updated Antigravity CLI (`agy 1.5.12`) model catalog (`agy models`) and live `/usage` output.
- Added support in `DetectedModel.swift` for `Gemini 4 Neon` (`N`), `Gemini 4 Carbon` (`C`), and `Orchestrator` planner variants (`Orchestrator (Neon)` -> `ON`, `Orchestrator (Argon)` -> `OA`, `Orchestrator (Carbon)` -> `OC`), while preserving parenthetical planner names when trailing parentheses are not reasoning effort levels (`Low`, `Medium`, `High`, `XHigh`, `Max`, `Thinking`).
- Updated `ModelQuotaMapper.swift` so `Orchestrator (Argon)` maps to the separate `Gemini 4 Argon` quota bucket while `Gemini 4 Neon`, `Orchestrator (Neon)`, `Gemini 4 Carbon`, and `Orchestrator (Carbon)` map to `Gemini Models`.
- Added unit tests covering `Gemini 4 Neon (XHigh)`, `Gemini 4 Carbon (High)`, `Orchestrator (Neon)`, `Orchestrator (Argon)`, and `Orchestrator (Carbon)` in `XcodeModelDetectorTests.swift` and `ModelQuotaMapperTests.swift`.
- Added a compact app logo (`docs/logo.png`) and updated `README.md` with the expanded model table, badges, effort tiers, and CLI notes.

### Milestone 9 — In-App Self-Updater, Stability Hardening & v1.2.0 Release
- Implemented `AppUpdateManager.swift` (`SemanticVersion`, `GitHubReleaseInfo`, `SystemAppUpdateNetworkClient`, `SystemAppUpdateInstaller`) for checking the latest GitHub release and performing one-click `.zip` download, `ditto` extraction, `xattr -cr` quarantine cleanup, bundle replacement, and app relaunch.
- Integrated `Check for Updates` / `Update` controls into `SettingsView.swift` and `MenuBarContentView.swift`, resetting transient update state when leaving Settings (`Done` / `onAppear` / `onDisappear`).
- Added unit tests in `AppUpdateManagerTests.swift` covering semantic version comparison, up-to-date status, available update installation flow, and network/extraction error handling.
- Guarded background polling in `AntigravityQuotaMonitorApp.init()` when running inside the unit test host (`XCTestConfigurationFilePath`) to prevent live background CLI/Accessibility polling during unit test execution.
- Updated `last-upgrade` in `AntigravityQuotaMonitor.xcodeproj/project.xcproj` to `27.2` to clear Xcode's `"Update to recommended settings"` project warning.
- Bumped version to `v1.2.0` (`MARKETING_VERSION = 1.2.0`, `CURRENT_PROJECT_VERSION = 3`), refreshed documentation screenshots, installed `/Applications/Antigravity Quota Monitor.app`, and published GitHub Release `v1.2.0`.

### Milestone 10 — Unified Gemini Quota Pool (Argon Merge) & Orchestrator Claude Opus 5.5 Support
- Verified live Antigravity CLI (`agy 1.5.16`) `/usage --output-format json` and `agy models` outputs following the November 23, 2026 Antigravity tier & quota updates:
  - Separate `Gemini 4 Argon` quota bucket removed for paid Pro plans and merged into the unified `Gemini Models` pool (`Gemini 4 Neon`, `Gemini 4 Carbon`, `Gemini 4 Argon`, `Gemini 4 Hydrogen`, `Orchestrator (Neon)`, `Orchestrator (Carbon)`, `Orchestrator (Argon)`, `Gemini 3.8 Flash`).
  - `Gemini 4 Carbon` expanded to paid Google AI Pro users and `Gemini 4 Hydrogen` opened to all users.
  - `Orchestrator` picker now supports `Claude Opus 5.5` as planner alongside Gemini 4 Neon, Carbon, and Argon.
- Updated `ModelQuotaMapper.swift`:
  - Argon models (`Gemini 4 Argon`, `Orchestrator (Argon)`) now fall through to the unified `Gemini Models` group when no separate Argon group is present, while keeping backward compatibility if an older CLI or tier still returns a separate `Gemini 4 Argon` group.
  - Third-party model/planner identifiers (`claude`, `opus`, `sonnet`, `gpt`) are now checked before the generic `orchestrator` fallback so `Orchestrator (Claude Opus 5.5)` / `Orchestrator (Opus)` map accurately to `Claude and GPT models`.
- Updated `DetectedModel.swift`:
  - Added Orchestrator planner abbreviations for `Opus` (`OO`), `Sonnet` (`OS`), and `Hydrogen` (`OH`) alongside `Neon` (`ON`), `Carbon` (`OC`), and `Argon` (`OA`).
  - Added `"extra high"` and `"x-high"` to recognized trailing effort descriptors.
- Updated unit test fixtures and added coverage in `AntigravityQuotaProviderTests.swift`, `ModelQuotaMapperTests.swift`, `XcodeModelDetectorTests.swift`, and `QuotaManagerTests.swift`, and refreshed `README.md`.

---

## Technical Decisions

1. **Product Name vs. Module Name Separation:** Setting `PRODUCT_NAME = "Antigravity Quota Monitor"` and `PRODUCT_MODULE_NAME = "AntigravityQuotaMonitor"` produces a user-friendly spaced `.app` bundle name in `/Applications` while keeping Swift module imports intact.
2. **Explicit Pipe Cleanup:** Closing `stdoutPipe` and `stderrPipe` read handles immediately after `readDataToEndOfFile()` (and on launch errors) guarantees zero descriptor leaks across long-running menu bar polling sessions.
3. **Privacy & Zero Raw Logging:** No conversation text, OAuth tokens, or raw CLI outputs are logged, cached on disk, or sent to custom endpoints.
4. **Effort vs. Planner Parenthetical Parsing:** `DetectedModel.parse` distinguishes trailing reasoning effort qualifiers (`(Low)`, `(Medium)`, `(High)`, `(XHigh)`, `(Extra High)`, `(Thinking)`) from model planner qualifiers (`Orchestrator (Neon)`, `Orchestrator (Carbon)`, `Orchestrator (Argon)`, `Orchestrator (Claude Opus 5.5)`) so planner identity is preserved for accurate quota group mapping and distinct menu bar abbreviations (`ON`, `OC`, `OA`, `OO`).
5. **Backward-Compatible Unified Gemini Pool Mapping:** `ModelQuotaMapper` prioritizes third-party planner/model names (`claude`, `opus`, `sonnet`, `gpt`) before generic `orchestrator` fallbacks, prefers a dedicated `Gemini 4 Argon` group only when explicitly present in a snapshot, and otherwise maps Argon seamlessly into the unified `Gemini Models` group.
6. **Detached Shell Swap for In-App Updates:** `SystemAppUpdateInstaller` extracts the downloaded release archive into a temporary staging directory, verifies the `.app` bundle, clears quarantine attributes, spawns a detached `/bin/sh` helper that waits for the current PID to terminate before replacing the app bundle via `ditto` and relaunching via `open -n`, and then terminates the running instance cleanly.

---

## Testing Results

- **Unit Tests (`AntigravityQuotaMonitorTests`):** `43 passed, 0 failed`, zero compiler or navigator warnings.
- **Live CLI & Xcode Integration Verification (`agy 1.5.16`):** Verified live `XcodeModelDetector` detection (`Gemini 4 Neon (Medium)` -> `N`) and live `AntigravityQuotaProvider` + `ModelQuotaMapper` resolution across all 20 Gemini 4, Orchestrator (Neon/Carbon/Argon/Claude Opus 5.5), Gemini 3.8 Flash, Claude 5.5, and GPT-OSS 120B variants against real `/usage` output.
- **Privacy & Security Audit:** Zero raw logging, zero credential handling, only public read-only GitHub Releases API requests when user clicks `Check for Updates`.

---

## Known Issues

- None blocking. Runtime behavior depends on macOS Accessibility permissions and the local `agy` CLI remaining compatible with `-p "/usage" --output-format json`.

---

## Git Information

- **Repository:** `https://github.com/GorkemSay/antigravity-quota-monitor`
- **Branch:** `main`
- **Release:** `v1.2.0` (`Antigravity-Quota-Monitor-macOS.zip`)
