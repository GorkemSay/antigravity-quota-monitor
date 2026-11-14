import SwiftUI

@main
struct AntigravityQuotaMonitorApp: App {
    static let appDisplayName = "Antigravity Quota Monitor"

    @State private var quotaManager: QuotaManager

    init() {
        let manager = QuotaManager()
        _quotaManager = State(initialValue: manager)
        Task { @MainActor in
            await manager.refreshAll()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(quotaManager: quotaManager)
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
