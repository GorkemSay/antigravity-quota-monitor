import Testing
@testable import AntigravityQuotaMonitor

struct AntigravityQuotaMonitorTests {
    @Test @MainActor
    func appDisplayNameIsConfigured() {
        #expect(AntigravityQuotaMonitorApp.appDisplayName == "Antigravity Quota Monitor")
    }
}
