# Antigravity Quota Monitor

A lightweight native macOS menu bar utility written in Swift and SwiftUI that monitors the remaining usage quota for the Google Antigravity AI model currently selected in Xcode.

> **Development Status:** Milestone 1 (Project Skeleton & Menu Bar Shell) is complete. Active Xcode model detection, Antigravity CLI quota retrieval, and live indicator updates are planned for upcoming milestones.

## Overview

Antigravity Quota Monitor is designed to live unobtrusively in the macOS menu bar (`LSUIElement`), detect which Antigravity AI model is selected in Xcode's built-in assistant, query real quota data through the official Antigravity CLI (`agy`), and surface the most restrictive remaining quota percentage at a glance (for example, `H 98%` or `A 99%`).

## Features

### Implemented (Milestone 1)

- Native macOS SwiftUI `MenuBarExtra` application shell (`AntigravityQuotaMonitor`)
- Menu bar agent configuration (`LSUIElement = YES`) with no Dock icon or standalone window
- Orbital menu bar icon using native SF Symbols (`atom`)
- Basic popover panel with application header and Quit action
- Swift Testing unit test target (`AntigravityQuotaMonitorTests`)

### Planned

- **Xcode Active Model Detection (Milestone 2):** Read the currently selected model name from Xcode's Accessibility hierarchy without modifying Xcode or intercepting conversations.
- **Official CLI Quota Retrieval (Milestone 3):** Execute `agy -p "/usage" --output-format json` asynchronously via `Process`, parse JSON safely, and track reset timestamps.
- **Model-to-Quota Mapping (Milestone 4):** Map detected models (Hydrogen, Argon, Flash, Claude, GPT) to their corresponding quota groups and select the lowest remaining percentage.
- **Expanded Menu Bar UI (Milestone 5):** Display active model abbreviation and percentage in the menu bar, detailed bucket progress bars, local-timezone reset times, other quota groups, and last refresh timestamp.
- **Background Refresh & Settings (Milestone 6):** Periodic refresh intervals, manual refresh, stale-data handling, launch-at-login via `ServiceManagement`, and configurable CLI executable path.

## Screenshots

Screenshots will be added once the live menu bar indicator and expanded quota panel are implemented in Milestone 5.

## System Requirements

- macOS 15.0 or later (tested on macOS 26.7.2, Apple Silicon)
- Xcode 16+ / Xcode 27.2+ (for building from source)
- Antigravity CLI (`agy`) installed locally and authenticated (required for Milestone 3+)
- macOS Accessibility permission granted to the application (required for Milestone 2+)

## Installation

Currently, the application is built from source using Xcode:

1. Clone the repository:
   ```bash
   git clone https://github.com/GorkemSay/antigravity-quota-monitor.git
   cd antigravity-quota-monitor
   ```
2. Open `Untitled Project.xcodeproj` in Xcode.
3. Select the **AntigravityQuotaMonitor** scheme and **My Mac** run destination.
4. Build and run (`Cmd + R`).

## Permissions and Privacy

- **Accessibility Permission (Planned in Milestone 2):** Required strictly to inspect the selected model label in Xcode's model picker control (`AXMenuButton`). The application does not collect source code, conversation history, or unrelated application data.
- **No App Sandbox (Local Execution):** App Sandbox is disabled on the macOS target so the app can invoke the user-installed `agy` CLI executable via `Process` and query Accessibility attributes from Xcode.
- **Credentials:** The application does not read, store, or extract OAuth tokens or authentication credentials.

## Antigravity CLI Requirements

When quota retrieval is integrated in Milestone 3, the application will rely on the locally installed Antigravity CLI (`agy`, verified on `1.5.9` at `~/.local/bin/agy`) and its structured JSON output:

```bash
agy -p "/usage" --output-format json
```

GUI applications launched from Finder or Xcode do not inherit interactive terminal `PATH` variables, so the planned provider will search standard user paths such as `$HOME/.local/bin/agy` and allow custom path configuration.

## How It Works (Architecture Overview)

1. **Xcode Model Detection (Planned):** `XcodeModelDetector` will locate the running Xcode process via `NSRunningApplication`, inspect the focused window using Apple's Accessibility APIs (`AXUIElement`), and read the model picker's accessibility label.
2. **Quota Retrieval (Planned):** `AntigravityQuotaProvider` will execute `agy -p "/usage" --output-format json` in a non-blocking subprocess with timeout and overlap protection, then decode `QuotaGroup` and `QuotaBucket` structures.
3. **Matching & Presentation (Planned):** `QuotaManager` will map the active model to its quota group, compute the lowest remaining quota percentage for the menu bar indicator, and preserve stale snapshots clearly if a refresh fails.

## Supported Model Groups (Observed CLI Configuration)

Based on observed CLI output on macOS (subject to account configuration and future CLI updates):

| Model | Quota Group | Observed Buckets |
|---|---|---|
| Gemini 4 Hydrogen | Gemini Models | Weekly, 5-hour |
| Gemini 3.8 Flash | Gemini Models | Weekly, 5-hour |
| Gemini 4 Argon | Gemini 4 Argon | Weekly |
| Claude Opus 5.5 | Claude and GPT models | Weekly, 5-hour |
| Claude Sonnet 5.5 | Claude and GPT models | Weekly, 5-hour |
| GPT-OSS 120B | Claude and GPT models | Weekly, 5-hour |

## Why This Approach?

### Built on Official Tools

Antigravity Quota Monitor is designed to retrieve usage information through Google's Antigravity CLI using its supported command-line interface.

Rather than depending on undocumented internal server endpoints, private authentication mechanisms, or intercepted application traffic, the application uses an existing CLI command to request structured usage information.

This reduces dependency on Antigravity's internal implementation details.

### Native Xcode Model Detection

The application is designed to identify the currently selected Antigravity model using Apple's Accessibility APIs.

It reads the model selection information exposed by Xcode's user interface without modifying Xcode, replacing its built-in agent, or intercepting AI conversations.

This enables automatic model-aware quota monitoring while preserving the user's existing development workflow.

### Privacy by Design

The application is designed to operate locally on macOS.

It does not independently collect authentication tokens, read conversation contents, or transmit usage information to application-operated third-party servers.

Quota requests will be performed through the installed Antigravity CLI, which may communicate with Google's services as part of its normal operation.

The application will request Accessibility permission only to obtain the model information required for its functionality.

### Reliability Through Separation of Concerns

Model detection, quota retrieval, data parsing, quota mapping, and user interface presentation are structured as independent components.

This architecture makes the application easier to test, maintain, and adapt when Antigravity or Xcode changes.

It also supports explicit error handling, controlled refresh intervals, and safeguards against displaying incorrect or outdated quota information.

### Transparent Limitations

Reliability does not mean guaranteed compatibility with every future version.

The application depends on the continued availability and compatibility of the Antigravity CLI usage command and Xcode's accessibility information.

CLI output formats, model names, quota groups, and Xcode accessibility hierarchies may change.

The application is designed to handle these changes gracefully and clearly communicate when information cannot be retrieved or verified.

### Engineering Principles

Our approach prioritizes:

- Officially provided tools and supported Apple APIs wherever possible.
- Minimal interference with Xcode and Antigravity.
- No direct handling of authentication credentials.
- Modular, testable Swift components.
- Accurate quota reporting with clearly indicated refresh times.
- Explicit error states instead of misleading fallback values.
- Low system resource consumption.
- Long-term maintainability.

> *Note: Antigravity Quota Monitor is an independent utility and is not endorsed by, certified by, or affiliated with Google or Apple.*

## Development Instructions

### Running Tests

Using Xcode, select the **AntigravityQuotaMonitor** scheme and press `Cmd + U`, or run via `xcodebuild`:

```bash
xcodebuild test \
  -project "Untitled Project.xcodeproj" \
  -scheme "AntigravityQuotaMonitor" \
  -destination "platform=macOS" \
  -only-testing:AntigravityQuotaMonitorTests
```

## Known Limitations

- In Milestone 1, only the menu bar application shell and test target exist; live model detection and quota retrieval are not yet implemented.
- The Xcode project container currently lives under `Untitled Project.xcodeproj` alongside the initial workspace template (`MyApp`).

## Roadmap

- [x] **Milestone 0:** Environment and feasibility review
- [x] **Milestone 1:** macOS Xcode target, menu bar shell, and GitHub repository setup
- [ ] **Milestone 2:** `XcodeModelDetector` via Accessibility APIs
- [ ] **Milestone 3:** `AntigravityQuotaProvider` via `agy` CLI
- [ ] **Milestone 4:** Model-to-quota mapping & `QuotaManager`
- [ ] **Milestone 5:** Full menu bar indicator and expanded popover UI
- [ ] **Milestone 6:** Background polling, stale-data states, and Settings
- [ ] **Milestone 7:** Comprehensive testing, polish, and local release build

## License

License to be determined (MIT License is under consideration).
