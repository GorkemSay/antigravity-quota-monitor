# Antigravity Quota Monitor

A lightweight native macOS menu bar utility written in Swift and SwiftUI that monitors the remaining usage quota for the Google Antigravity AI model currently selected in Xcode.

> **Development Status:** Milestone 3 (CLI Quota Provider) is complete. Model-to-quota group integration and the full menu bar quota display are planned for Milestones 4–5.

## Overview

Antigravity Quota Monitor is designed to live unobtrusively in the macOS menu bar (`LSUIElement`), detect which Antigravity AI model is selected in Xcode's built-in assistant, query real quota data through the official Antigravity CLI (`agy`), and surface the most restrictive remaining quota percentage at a glance (for example, `H 98%` or `A 99%`).

## Features

### Implemented (Milestones 1–3)

- Native macOS SwiftUI `MenuBarExtra` application shell (`AntigravityQuotaMonitor`)
- Menu bar agent configuration (`LSUIElement = YES`) with no Dock icon or standalone window
- Orbital menu bar icon using native SF Symbols (`atom`)
- `XcodeModelDetector` service inspecting Xcode's Accessibility tree (`AXMenuButton`, `Help == "Model"`) across focused, main, and secondary Xcode windows
- `DetectedModel` parser normalizing model names, effort tiers (e.g., `(High)`, `(Medium)`), and short abbreviations (`H`, `A`, `F`, `O`, `S`, `G`)
- `AntigravityQuotaProvider` actor executing `agy -p "/usage" --output-format json` asynchronously with configurable executable discovery (`$HOME/.local/bin/agy`, Homebrew/system paths, or custom path), timeout protection, and in-flight call coalescing (no overlapping subprocesses)
- Quote- and escape-aware balanced JSON extraction (`QuotaCLIResponseParser`) supporting optional fields and trailing text
- Swift Testing unit test suites (`AntigravityQuotaMonitorTests`)

### Planned

- **Model-to-Quota Mapping (Milestone 4):** Map detected models (Hydrogen, Argon, Flash, Claude, GPT) to their corresponding quota groups and select the lowest remaining percentage via `QuotaManager`.
- **Expanded Menu Bar UI (Milestone 5):** Display active model abbreviation and percentage in the menu bar, detailed bucket progress bars, local-timezone reset times, other quota groups, and last refresh timestamp.
- **Background Refresh & Settings (Milestone 6):** Periodic refresh intervals, manual refresh, stale-data handling, launch-at-login via `ServiceManagement`, and configurable CLI executable path in Settings.

## Screenshots

Screenshots will be added once the live menu bar indicator and expanded quota panel are implemented in Milestone 5.

## System Requirements

- macOS 15.0 or later (tested on macOS 26.7.2, Apple Silicon)
- Xcode 16+ / Xcode 27.2+ (for building from source)
- macOS Accessibility permission granted to `AntigravityQuotaMonitor` (required for active model detection)
- Antigravity CLI (`agy`) installed locally and authenticated (verified on `1.5.9`)

## Installation

Currently, the application is built from source using Xcode:

1. Clone the repository:
   ```bash
   git clone https://github.com/GorkemSay/antigravity-quota-monitor.git
   cd antigravity-quota-monitor
   ```
2. Open `AntigravityQuotaMonitor.xcodeproj` in Xcode.
3. Select the **AntigravityQuotaMonitor** scheme and **My Mac** run destination.
4. Build and run (`Cmd + R`).
5. When prompted (or via **System Settings > Privacy & Security > Accessibility**), grant Accessibility permission to **AntigravityQuotaMonitor**.

## Permissions and Privacy

- **Accessibility Permission:** Required strictly to inspect the selected model label in Xcode's model picker control (`AXMenuButton`). The application does not collect source code, conversation history, or unrelated application data.
- **No App Sandbox (Local Execution):** App Sandbox is disabled on the macOS target so the app can query Accessibility attributes from Xcode and invoke the user-installed `agy` CLI executable via `Process`.
- **Credentials & Logging:** The application does not read, store, or extract OAuth tokens or authentication credentials, and does not log raw CLI output by default.

## Antigravity CLI Requirements

The application invokes the locally installed Antigravity CLI (`agy`, verified on `1.5.9` at `~/.local/bin/agy`) using:

```bash
agy -p "/usage" --output-format json
```

Because macOS GUI applications launched from Finder or Xcode do not inherit interactive terminal `PATH` variables, `AntigravityQuotaProvider` checks `$HOME/.local/bin/agy`, `/opt/homebrew/bin/agy`, `/usr/local/bin/agy`, `/usr/bin/agy`, `PATH` entries, and an optional custom executable path.

## How It Works (Architecture Overview)

1. **Xcode Model Detection (Implemented in Milestone 2):** `XcodeModelDetector` locates running Xcode processes via `NSRunningApplication`, inspects focused, main, and secondary Xcode windows using Apple's Accessibility APIs (`AXUIElement`), and parses the model picker's accessibility label into `DetectedModel`.
2. **Quota Retrieval (Implemented in Milestone 3):** `AntigravityQuotaProvider` executes `agy -p "/usage" --output-format json` in a non-blocking subprocess with timeout and overlap protection, extracts balanced JSON safely, and decodes `QuotaSnapshot`, `QuotaGroup`, and `QuotaBucket` models.
3. **Matching & Presentation (Planned in Milestones 4–5):** `QuotaManager` will map the active model to its quota group, compute the lowest remaining quota percentage for the menu bar indicator, and preserve stale snapshots clearly if a refresh fails.

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

Antigravity Quota Monitor retrieves usage information through Google's Antigravity CLI using its supported command-line interface.

Rather than depending on undocumented internal server endpoints, private authentication mechanisms, or intercepted application traffic, the application uses an existing CLI command to request structured usage information.

This reduces dependency on Antigravity's internal implementation details.

### Native Xcode Model Detection

The application identifies the currently selected Antigravity model using Apple's Accessibility APIs.

It reads the model selection information exposed by Xcode's user interface without modifying Xcode, replacing its built-in agent, or intercepting AI conversations.

This enables automatic model-aware quota monitoring while preserving the user's existing development workflow.

### Privacy by Design

The application operates locally on macOS.

It does not independently collect authentication tokens, read conversation contents, or transmit usage information to application-operated third-party servers.

Quota requests are performed through the installed Antigravity CLI, which may communicate with Google's services as part of its normal operation.

The application requests Accessibility permission only to obtain the model information required for its functionality.

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
  -project "AntigravityQuotaMonitor.xcodeproj" \
  -scheme "AntigravityQuotaMonitor" \
  -destination "platform=macOS" \
  -only-testing:AntigravityQuotaMonitorTests
```

## Known Limitations

- Model-to-quota group mapping and live quota UI integration are not yet connected (scheduled for Milestones 4–5).
- Live model detection requires macOS Accessibility permission to be granted to the running application bundle.

## Roadmap

- [x] **Milestone 0:** Environment and feasibility review
- [x] **Milestone 1:** macOS Xcode target, menu bar shell, and GitHub repository setup
- [x] **Milestone 2:** `XcodeModelDetector` via Accessibility APIs
- [x] **Milestone 3:** `AntigravityQuotaProvider` via `agy` CLI
- [ ] **Milestone 4:** Model-to-quota mapping & `QuotaManager`
- [ ] **Milestone 5:** Full menu bar indicator and expanded popover UI
- [ ] **Milestone 6:** Background polling, stale-data states, and Settings
- [ ] **Milestone 7:** Comprehensive testing, polish, and local release build

## License

This project is licensed under the [MIT License](LICENSE).
