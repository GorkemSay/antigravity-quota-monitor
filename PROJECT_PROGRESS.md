# Project Progress — Antigravity Quota Monitor

## Project Overview

**Antigravity Quota Monitor** is a native macOS SwiftUI menu bar utility that detects the currently selected Antigravity AI model in Xcode via Apple's Accessibility APIs and displays real remaining usage quota retrieved via the official Antigravity CLI (`agy`).

- **Repository:** `https://github.com/GorkemSay/antigravity-quota-monitor` (Public)
- **Platform:** macOS 15.0+ (developed on macOS 26.7.2, Xcode 27.2, Swift 6.4.2)
- **Architecture:** Modular SwiftUI (`MenuBarExtra`) + isolated domain services (`XcodeModelDetector`, `AntigravityQuotaProvider`, `ModelQuotaMapper`, `QuotaManager`)

---

## Current Milestone

**Milestone 1 — Xcode Project and GitHub Repository** (Completed)

---

## Completed Tasks

### Milestone 0 — Environment and Feasibility Review
- Verified Swift `6.4.2`, Xcode `27.2`, macOS `26.7.2` (`arm64`), Git `2.54.0`, and GitHub CLI `2.103.2` (`GorkemSay` authenticated).
- Verified Antigravity CLI `/Users/gorkemsay/.local/bin/agy` (`1.5.9`).
- Reviewed working Accessibility prototype `~/Downloads/XcodeActiveModelProbe_fixed.swift`.
- Identified key technical constraints: App Sandbox must be disabled for external CLI subprocess execution, `LSUIElement` is required for menu bar agent behavior, and SF Symbol `"orbit"` is unavailable on macOS whereas `"atom"` is available.

### Milestone 1 — Xcode Project and GitHub Repository
- Created native macOS targets `AntigravityQuotaMonitor`, `AntigravityQuotaMonitorTests` (Swift Testing), and `AntigravityQuotaMonitorUITests` inside `Untitled Project.xcodeproj`.
- Configured `AntigravityQuotaMonitor` build settings:
  - `SUPPORTED_PLATFORMS = macosx`, `SDKROOT = macosx`
  - `MACOSX_DEPLOYMENT_TARGET = 15.0`
  - `ENABLE_APP_SANDBOX = NO`
  - `INFOPLIST_KEY_LSUIElement = YES`
  - `PRODUCT_BUNDLE_IDENTIFIER = com.gorkemsay.AntigravityQuotaMonitor`
  - `DEVELOPMENT_TEAM = C9VY6L4QAS`
- Implemented minimal `MenuBarExtra` entry point in `AntigravityQuotaMonitor/App/AntigravityQuotaMonitorApp.swift` and minimal popover in `AntigravityQuotaMonitor/Views/MenuBarContentView.swift` using SF Symbol `"atom"`.
- Added initial Swift Testing verification in `AntigravityQuotaMonitorTests/AntigravityQuotaMonitorTests.swift`.
- Created `.gitignore`, `README.md` (including the `Why This Approach?` architectural section), and `PROJECT_PROGRESS.md`.
- Verified project builds for testing and `AntigravityQuotaMonitorTests` passes.

---

## Technical Decisions

1. **Workspace Placement:** Added `AntigravityQuotaMonitor` targets within the active Xcode workspace (`Untitled Project.xcodeproj`) so Xcode MCP tools (`BuildProject`, `RunSomeTests`, `XcodeWrite`) operate natively on the project without leaving unrelated `MyApp` target broken or modified.
2. **App Sandbox Disabled (`ENABLE_APP_SANDBOX = NO`):** Required because the app must execute the external user-installed `agy` CLI binary via `Foundation.Process` and access Xcode's Accessibility tree.
3. **Menu Bar Agent (`INFOPLIST_KEY_LSUIElement = YES`):** Prevents the app from appearing in the Dock or Cmd+Tab switcher, matching standard macOS menu bar utilities.
4. **Menu Bar Icon (`atom` SF Symbol):** Verified via AppKit `NSImage(systemSymbolName:)` that `"orbit"` does not exist in SF Symbols on macOS 26.7.2, while `"atom"` exists and conveys the Antigravity orbital theme natively in light/dark mode.
5. **macOS 15.0 Deployment Target:** Selected `15.0` instead of `26.7` so the binary remains compatible across recent Apple Silicon macOS releases while retaining modern SwiftUI and Swift Testing support.

---

## Testing Results

- `BuildProject (buildForTesting: true)` on scheme `AntigravityQuotaMonitor` (My Mac): **Succeeded** (0 errors).
- `RunSomeTests` (`AntigravityQuotaMonitorTests/appDisplayNameIsConfigured()`): **1 passed, 0 failed**.

---

## Known Issues

- The `.xcodeproj` container is currently named `Untitled Project.xcodeproj` and retains the original empty `MyApp` template target alongside `AntigravityQuotaMonitor`.
- Live model detection, CLI quota retrieval, and settings are not yet implemented (scheduled for Milestones 2–6).
- License file has not been added yet pending explicit user confirmation (MIT proposed).

---

## Next Steps

**Milestone 2 — Active Model Detection**
- Implement `XcodeModelDetector` in `AntigravityQuotaMonitor/Services/` reusing the verified CoreFoundation/Accessibility pattern from `XcodeActiveModelProbe_fixed.swift`.
- Handle missing Accessibility permissions (`AXIsProcessTrustedWithOptions`), Xcode not running, no open conversation, and multiple windows.
- Add unit tests for model parsing/state handling and verify live switching between Gemini Hydrogen and Gemini Argon in Xcode.

---

## Git Information

- **Repository:** `https://github.com/GorkemSay/antigravity-quota-monitor`
- **Branch:** `main`
- **Latest Commit:** Initial commit pushed in Milestone 1 (updated after push).
