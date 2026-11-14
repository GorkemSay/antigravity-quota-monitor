import Foundation
import Testing
@testable import AntigravityQuotaMonitor

private final class MockLaunchAtLoginController: LaunchAtLoginControlling, @unchecked Sendable {
    var isEnabled: Bool
    var errorToThrow: Error?

    init(isEnabled: Bool = false, errorToThrow: Error? = nil) {
        self.isEnabled = isEnabled
        self.errorToThrow = errorToThrow
    }

    func setEnabled(_ enabled: Bool) throws {
        if let errorToThrow {
            throw errorToThrow
        }
        isEnabled = enabled
    }
}

private enum MockLaunchError: LocalizedError {
    case registrationDenied

    var errorDescription: String? {
        "Registration denied by system."
    }
}

@Suite("PreferencesStore")
struct PreferencesStoreTests {
    @Test
    @MainActor
    func persistsDefaultsClampsIntervalsAndNormalizesCLIPath() throws {
        let suiteName = "PreferencesStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let controller = MockLaunchAtLoginController()
        let store = PreferencesStore(userDefaults: defaults, launchController: controller)

        #expect(store.refreshIntervalMinutes == 3)
        #expect(store.refreshIntervalSeconds == 180)
        #expect(store.normalizedCustomCLIPath == nil)

        store.refreshIntervalMinutes = 1
        #expect(store.refreshIntervalMinutes == 2)

        store.refreshIntervalMinutes = 12
        #expect(store.refreshIntervalMinutes == 5)

        store.customCLIPath = "  ~/bin/agy  "
        #expect(store.normalizedCustomCLIPath == "~/bin/agy")

        let reloaded = PreferencesStore(userDefaults: defaults, launchController: controller)
        #expect(reloaded.refreshIntervalMinutes == 5)
        #expect(reloaded.normalizedCustomCLIPath == "~/bin/agy")
    }

    @Test
    @MainActor
    func updatesLaunchAtLoginAndHandlesRegistrationFailure() throws {
        let suiteName = "PreferencesStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let controller = MockLaunchAtLoginController(isEnabled: false)
        let store = PreferencesStore(userDefaults: defaults, launchController: controller)

        store.setLaunchAtLogin(true)
        #expect(store.launchAtLoginEnabled == true)
        #expect(store.launchAtLoginError == nil)

        controller.errorToThrow = MockLaunchError.registrationDenied
        store.setLaunchAtLogin(false)
        #expect(store.launchAtLoginEnabled == true)
        #expect(store.launchAtLoginError?.contains("Registration denied") == true)
    }
}
