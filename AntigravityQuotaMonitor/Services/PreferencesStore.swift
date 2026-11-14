import Foundation
import Observation
import ServiceManagement

nonisolated protocol LaunchAtLoginControlling: Sendable {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

nonisolated struct SystemLaunchAtLoginController: LaunchAtLoginControlling {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

@MainActor
@Observable
final class PreferencesStore {
    static let allowedRefreshIntervals = [2, 3, 4, 5]
    static let defaultRefreshIntervalMinutes = 3

    private enum Keys {
        static let refreshIntervalMinutes = "refreshIntervalMinutes"
        static let customCLIPath = "customCLIPath"
    }

    private let userDefaults: UserDefaults
    private let launchController: any LaunchAtLoginControlling

    var refreshIntervalMinutes: Int {
        didSet {
            let clamped = Self.clampInterval(refreshIntervalMinutes)
            if refreshIntervalMinutes != clamped {
                refreshIntervalMinutes = clamped
                return
            }
            userDefaults.set(clamped, forKey: Keys.refreshIntervalMinutes)
        }
    }

    var customCLIPath: String {
        didSet {
            userDefaults.set(customCLIPath, forKey: Keys.customCLIPath)
        }
    }

    private(set) var launchAtLoginEnabled: Bool
    private(set) var launchAtLoginError: String?

    init(
        userDefaults: UserDefaults = .standard,
        launchController: any LaunchAtLoginControlling = SystemLaunchAtLoginController()
    ) {
        self.userDefaults = userDefaults
        self.launchController = launchController

        let storedInterval = userDefaults.object(forKey: Keys.refreshIntervalMinutes) as? Int
        self.refreshIntervalMinutes = Self.clampInterval(storedInterval ?? Self.defaultRefreshIntervalMinutes)
        self.customCLIPath = userDefaults.string(forKey: Keys.customCLIPath) ?? ""
        self.launchAtLoginEnabled = launchController.isEnabled
    }

    var refreshIntervalSeconds: TimeInterval {
        TimeInterval(refreshIntervalMinutes * 60)
    }

    var normalizedCustomCLIPath: String? {
        let trimmed = customCLIPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        do {
            try launchController.setEnabled(enabled)
            launchAtLoginEnabled = launchController.isEnabled
        } catch {
            launchAtLoginEnabled = launchController.isEnabled
            launchAtLoginError = "Could not update Launch at Login: \(error.localizedDescription)"
        }
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = launchController.isEnabled
    }

    private static func clampInterval(_ minutes: Int) -> Int {
        if minutes < 2 { return 2 }
        if minutes > 5 { return 5 }
        return minutes
    }
}
