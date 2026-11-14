import SwiftUI

@main
struct AntigravityQuotaMonitorApp: App {
    static let appDisplayName = "Antigravity Quota Monitor"

    @State private var preferences: PreferencesStore
    @State private var quotaManager: QuotaManager

    init() {
        let prefs = PreferencesStore()
        let manager = QuotaManager(refreshInterval: prefs.refreshIntervalSeconds)
        _preferences = State(initialValue: prefs)
        _quotaManager = State(initialValue: manager)

        Task { @MainActor in
            await manager.updateCustomCLIPath(prefs.normalizedCustomCLIPath)
            await manager.refreshAll()
            manager.startBackgroundPolling()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(
                quotaManager: quotaManager,
                preferences: preferences
            )
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "atom")
                .accessibilityLabel(Self.appDisplayName)

            if let displayText = quotaManager.menuBarDisplayText {
                Text(displayText)
                    .monospacedDigit()
            } else if quotaManager.isRefreshing && quotaManager.snapshot == nil {
                Text("…")
            }
        }
    }
}
