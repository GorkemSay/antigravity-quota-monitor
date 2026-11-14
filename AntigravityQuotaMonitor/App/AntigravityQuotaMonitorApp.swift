import SwiftUI

@main
struct AntigravityQuotaMonitorApp: App {
    static let appDisplayName = "Antigravity Quota Monitor"

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
        } label: {
            Label(Self.appDisplayName, systemImage: "atom")
                .labelStyle(.iconOnly)
        }
        .menuBarExtraStyle(.window)
    }
}
