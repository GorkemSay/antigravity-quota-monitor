# Project Progress — Antigravity Quota Monitor

## Project Overview

**Antigravity Quota Monitor** is a native macOS SwiftUI menu bar utility that detects the currently selected Antigravity AI model in Xcode via Apple's Accessibility APIs and displays real remaining usage quota retrieved via the official Antigravity CLI (`agy`).

- **Repository:** `https://github.com/GorkemSay/antigravity-quota-monitor` (Public)
- **License:** MIT (`LICENSE`)
- **Platform:** macOS 15.0+ (developed on macOS 26.7.2, Xcode 27.2, Swift 6.4.2)
- **Architecture:** Modular SwiftUI (`MenuBarExtra`) + isolated domain services (`XcodeModelDetector`, `AntigravityQuotaProvider`, `ModelQuotaMapper`, `QuotaManager`)

---

## Current Milestone

**Milestone 2 — Active Model Detection** (Completed)

---

## Completed Tasks

### Milestone 0 — Environment and Feasibility Review
- Verified Swift `6.4.2`, Xcode `27.2`, macOS `26.7.2` (`arm64`), Git `2.54.0`, and GitHub CLI `2.103.2` (`GorkemSay` authenticated).
- Verified Antigravity CLI `/Users/gorkemsay/.local/bin/agy` (`1.5.9`).
- Reviewed working Accessibility prototype `~/Downloads/XcodeActiveModelProbe_fixed.swift`.

### Milestone 1 — Xcode Project and GitHub Repository
- Created native macOS targets `AntigravityQuotaMonitor`, `AntigravityQuotaMonitorTests` (Swift Testing), and `AntigravityQuotaMonitorUITests`.
- Configured macOS-only build settings (`MACOSX_DEPLOYMENT_TARGET = 15.0`, `ENABLE_APP_SANDBOX = NO`, `INFOPLIST_KEY_LSUIElement = YES`).
- Implemented minimal `MenuBarExtra` entry point (`atom` SF Symbol) and initial Swift Testing verification.
- Initialized Git and created public GitHub repository `GorkemSay/antigravity-quota-monitor`.
- Subsequently cleaned up template `MyApp` target, renamed `Untitled Project.xcodeproj` to `AntigravityQuotaMonitor.xcodeproj`, and added MIT `LICENSE`.

### Milestone 2 — Active Model Detection
- Added `AntigravityQuotaMonitor/Models/DetectedModel.swift` to parse raw Xcode model picker labels (e.g., `"Gemini 4 Hydrogen (High)"`, `"Gemini 4 Argon (Medium)"`) into normalized names, optional effort levels, and short abbreviations (`H`, `A`, `F`, `O`, `S`, `G`), while rejecting empty or parenthetical-only strings.
- Added `AntigravityQuotaMonitor/Services/XcodeModelDetector.swift` with `AccessibilityTreeReading` abstraction and `LiveAccessibilityTreeReader` using CoreFoundation-validated `AXUIElement` traversal (`kAXFocusedWindowAttribute`, `kAXMainWindowAttribute`, `kAXWindowsAttribute`, `AXMenuButton` + `kAXHelpAttribute == "Model"`), bounded depth (`40`) and node (`6000` per root) guards.
- Added explicit handling for `.permissionRequired` (plus `requestAccessibilityPermissionPrompt()`), `.xcodeNotRunning`, and `.modelNotFound(inspectedNodes:)`.
- Updated `MenuBarContentView.swift` to surface active model detection state and provide `Check Model` and `Grant Accessibility Access` actions.
- Added unit tests in `AntigravityQuotaMonitorTests/XcodeModelDetectorTests.swift` covering parsing, permissions, missing Xcode, multi-window fallback, missing conversation, and node limit guards.

---

## Technical Decisions

1. **Project Rename & Template Cleanup:** Renamed `Untitled Project.xcodeproj` to `AntigravityQuotaMonitor.xcodeproj` and removed the template `MyApp` target/folder so the repository reflects a clean single-purpose macOS project.
2. **Protocol-Backed Accessibility Reader:** Extracted `AccessibilityTreeReading` in `XcodeModelDetector.swift` so traversal logic, multi-window fallback, and edge cases are 100% deterministically unit-testable without requiring TCC permissions in headless test runners, while `LiveAccessibilityTreeReader` executes the verified CoreFoundation `AXUIElement` logic in production.
3. **Off-Main-Thread Inspection:** `XcodeModelDetector.detectActiveModel()` runs AX inspection inside `Task.detached(priority: .utility)` so the menu bar UI remains responsive even if Xcode's accessibility tree is large or busy.
4. **Prompt Discipline:** `AXIsProcessTrusted()` is used during checks; `AXIsProcessTrustedWithOptions` with prompt is triggered only when the user clicks **Grant Accessibility Access**.

---

## Testing Results

- `xcodebuild test -project AntigravityQuotaMonitor.xcodeproj -scheme AntigravityQuotaMonitor -destination 'platform=macOS' -only-testing:AntigravityQuotaMonitorTests`: **11 passed, 0 failed** (3 suites: `AntigravityQuotaMonitorTests`, `DetectedModel Parsing`, `XcodeModelDetector`).
- Live non-interactive CLI probe of `XcodeModelDetector().detectActiveModelSync()` cleanly returned `.permissionRequired` when launched from a process without macOS Accessibility permission.

---

## Known Issues

- Live model switching in `AntigravityQuotaMonitor.app` requires granting macOS Accessibility permission to the built `AntigravityQuotaMonitor.app` bundle in System Settings; the headless test runner does not hold TCC Accessibility permission.
- CLI quota retrieval (`agy`) and quota group matching are not yet implemented (Milestones 3–4).

---

## Next Steps

**Milestone 3 — CLI Quota Provider**
- Implement `QuotaModels.swift` (`QuotaBucket`, `QuotaGroup`, `QuotaSnapshot`) and `AntigravityQuotaProvider.swift`.
- Discover `agy` executable path safely (defaulting to `$HOME/.local/bin/agy` plus configurable path).
- Execute `agy -p "/usage" --output-format json` asynchronously via `Process` with timeout protection, no overlapping executions, and quote/escape-aware JSON extraction.
- Add unit tests using real and malformed CLI fixture outputs.

---

## Git Information

- **Repository:** `https://github.com/GorkemSay/antigravity-quota-monitor`
- **Branch:** `main`
- **Latest Commit:** Updated upon Milestone 2 completion.
