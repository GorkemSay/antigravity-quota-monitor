import Foundation
import Testing
@testable import AntigravityQuotaMonitor

private actor MockUpdateNetworkClient: AppUpdateNetworking {
    var releaseResult: Result<GitHubReleaseInfo, Error>
    var downloadResult: Result<URL, Error>
    private(set) var fetchedURLs: [URL] = []
    private(set) var downloadedURLs: [URL] = []

    init(
        releaseResult: Result<GitHubReleaseInfo, Error>,
        downloadResult: Result<URL, Error> = .success(URL(fileURLWithPath: "/tmp/mock-update.zip"))
    ) {
        self.releaseResult = releaseResult
        self.downloadResult = downloadResult
    }

    func fetchLatestRelease(from url: URL) async throws -> GitHubReleaseInfo {
        fetchedURLs.append(url)
        return try releaseResult.get()
    }

    func downloadArchive(from url: URL) async throws -> URL {
        downloadedURLs.append(url)
        return try downloadResult.get()
    }
}

private actor MockUpdateInstaller: AppUpdateInstalling {
    var errorToThrow: Error?
    private(set) var installedArchiveURL: URL?
    private(set) var installedTargetURL: URL?
    private(set) var installedPID: pid_t?

    init(errorToThrow: Error? = nil) {
        self.errorToThrow = errorToThrow
    }

    func installAndRelaunch(
        archiveFileURL: URL,
        targetAppBundleURL: URL,
        currentProcessID: pid_t,
        terminateCurrentApp: @MainActor @Sendable () -> Void
    ) async throws {
        if let errorToThrow {
            throw errorToThrow
        }
        installedArchiveURL = archiveFileURL
        installedTargetURL = targetAppBundleURL
        installedPID = currentProcessID
        await terminateCurrentApp()
    }
}

@Suite("AppUpdateManager")
struct AppUpdateManagerTests {
    static let sampleNewerRelease = GitHubReleaseInfo(
        tagName: "v1.2.0",
        htmlURL: URL(string: "https://github.com/GorkemSay/antigravity-quota-monitor/releases/tag/v1.2.0")!,
        assets: [
            GitHubReleaseAsset(
                name: "Antigravity-Quota-Monitor-macOS.zip",
                browserDownloadURL: URL(string: "https://github.com/GorkemSay/antigravity-quota-monitor/releases/download/v1.2.0/Antigravity-Quota-Monitor-macOS.zip")!
            )
        ]
    )

    @Test
    func semanticVersionComparesVersionsAccurately() {
        #expect(SemanticVersion.isRemoteNewer(remote: "v1.2.0", current: "1.1.0") == true)
        #expect(SemanticVersion.isRemoteNewer(remote: "1.1.1", current: "v1.1.0") == true)
        #expect(SemanticVersion.isRemoteNewer(remote: "v2.0", current: "1.9.9") == true)
        #expect(SemanticVersion.isRemoteNewer(remote: "v1.1.0", current: "1.1.0") == false)
        #expect(SemanticVersion.isRemoteNewer(remote: "v1.0.9", current: "1.1.0") == false)
    }

    @Test
    @MainActor
    func reportsUpToDateWhenCurrentVersionMatchesOrExceedsLatestRelease() async {
        let sameRelease = GitHubReleaseInfo(
            tagName: "v1.1.0",
            htmlURL: URL(string: "https://github.com/GorkemSay/antigravity-quota-monitor/releases/tag/v1.1.0")!,
            assets: []
        )
        let network = MockUpdateNetworkClient(releaseResult: .success(sameRelease))
        let installer = MockUpdateInstaller()
        let manager = AppUpdateManager(
            currentVersion: "1.1.0",
            networkClient: network,
            installer: installer,
            terminateApp: {}
        )

        await manager.checkForUpdates()
        #expect(manager.state == .upToDate(version: "v1.1.0"))

        manager.resetState()
        #expect(manager.state == .idle)

        await manager.checkForUpdates()
        #expect(manager.state == .upToDate(version: "v1.1.0"))
    }

    @Test
    @MainActor
    func detectsAvailableUpdateAndInstallsCleanly() async {
        let archiveURL = URL(fileURLWithPath: "/tmp/Antigravity-Quota-Monitor-macOS.zip")
        let targetBundleURL = URL(fileURLWithPath: "/Applications/Antigravity Quota Monitor.app")
        let network = MockUpdateNetworkClient(
            releaseResult: .success(Self.sampleNewerRelease),
            downloadResult: .success(archiveURL)
        )
        let installer = MockUpdateInstaller()
        var didTerminate = false

        let manager = AppUpdateManager(
            currentVersion: "1.1.0",
            currentBundleURL: targetBundleURL,
            currentProcessID: 4242,
            networkClient: network,
            installer: installer,
            terminateApp: { didTerminate = true }
        )

        await manager.checkForUpdates()
        #expect(manager.state == .updateAvailable(Self.sampleNewerRelease))

        await manager.performUpdate(to: Self.sampleNewerRelease)
        #expect(await installer.installedArchiveURL == archiveURL)
        #expect(await installer.installedTargetURL == targetBundleURL)
        #expect(await installer.installedPID == 4242)
        #expect(didTerminate == true)
    }

    @Test
    @MainActor
    func surfacesErrorsWhenCheckOrUpdateFails() async {
        let failingNetwork = MockUpdateNetworkClient(
            releaseResult: .failure(AppUpdateError.invalidHTTPStatus(503))
        )
        let installer = MockUpdateInstaller()
        let manager = AppUpdateManager(
            currentVersion: "1.1.0",
            networkClient: failingNetwork,
            installer: installer,
            terminateApp: {}
        )

        await manager.checkForUpdates()
        if case .failed(let message) = manager.state {
            #expect(message.contains("503"))
        } else {
            Issue.record("Expected failed state on HTTP 503")
        }

        let releaseWithoutZip = GitHubReleaseInfo(
            tagName: "v1.2.0",
            htmlURL: URL(string: "https://github.com/GorkemSay/antigravity-quota-monitor/releases/tag/v1.2.0")!,
            assets: []
        )
        await manager.performUpdate(to: releaseWithoutZip)
        if case .failed(let message) = manager.state {
            #expect(message.contains(".zip"))
        } else {
            Issue.record("Expected failed state when zip asset is missing")
        }
    }
}
