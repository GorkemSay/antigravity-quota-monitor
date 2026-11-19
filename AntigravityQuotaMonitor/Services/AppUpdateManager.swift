import AppKit
import Foundation
import Observation

nonisolated struct GitHubReleaseAsset: Sendable, Equatable, Decodable {
    let name: String
    let browserDownloadURL: URL

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

nonisolated struct GitHubReleaseInfo: Sendable, Equatable, Decodable {
    let tagName: String
    let htmlURL: URL
    let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }

    var normalizedVersion: String {
        SemanticVersion.normalize(tagName)
    }

    var displayTag: String {
        let trimmed = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("v") {
            return trimmed
        }
        return "v\(trimmed)"
    }

    var preferredZipAsset: GitHubReleaseAsset? {
        if let exact = assets.first(where: { $0.name == "Antigravity-Quota-Monitor-macOS.zip" }) {
            return exact
        }
        return assets.first(where: { $0.name.lowercased().hasSuffix(".zip") })
    }
}

nonisolated enum SemanticVersion: Sendable {
    static func normalize(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.lowercased().hasPrefix("v") {
            value.removeFirst()
        }
        if let dashIndex = value.firstIndex(of: "-") {
            value = String(value[..<dashIndex])
        }
        return value
    }

    static func isRemoteNewer(remote: String, current: String) -> Bool {
        let remoteParts = components(of: remote)
        let currentParts = components(of: current)
        let maxCount = max(remoteParts.count, currentParts.count)

        guard maxCount > 0 else { return false }

        for index in 0..<maxCount {
            let remoteValue = index < remoteParts.count ? remoteParts[index] : 0
            let currentValue = index < currentParts.count ? currentParts[index] : 0
            if remoteValue != currentValue {
                return remoteValue > currentValue
            }
        }
        return false
    }

    private static func components(of raw: String) -> [Int] {
        normalize(raw)
            .split(separator: ".")
            .map { Int($0) ?? 0 }
    }
}

nonisolated enum AppUpdateError: Error, LocalizedError, Sendable, Equatable {
    case invalidHTTPStatus(Int)
    case invalidReleasePayload
    case missingDownloadAsset
    case downloadFailed(String)
    case extractionFailed(String)
    case extractedAppBundleNotFound
    case installLaunchFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidHTTPStatus(let code):
            return "GitHub Releases returned HTTP \(code)."
        case .invalidReleasePayload:
            return "Could not parse the latest release information from GitHub."
        case .missingDownloadAsset:
            return "No macOS .zip archive was found in the latest GitHub release."
        case .downloadFailed(let detail):
            return "Failed to download update archive: \(detail)"
        case .extractionFailed(let detail):
            return "Failed to extract update archive: \(detail)"
        case .extractedAppBundleNotFound:
            return "The downloaded update archive did not contain Antigravity Quota Monitor.app."
        case .installLaunchFailed(let detail):
            return "Failed to start the update installer: \(detail)"
        }
    }
}

nonisolated protocol AppUpdateNetworking: Sendable {
    func fetchLatestRelease(from url: URL) async throws -> GitHubReleaseInfo
    func downloadArchive(from url: URL) async throws -> URL
}

nonisolated protocol AppUpdateInstalling: Sendable {
    func installAndRelaunch(
        archiveFileURL: URL,
        targetAppBundleURL: URL,
        currentProcessID: pid_t,
        terminateCurrentApp: @MainActor @Sendable () -> Void
    ) async throws
}

nonisolated struct SystemAppUpdateNetworkClient: AppUpdateNetworking {
    static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/GorkemSay/antigravity-quota-monitor/releases/latest"
    )!

    func fetchLatestRelease(from url: URL) async throws -> GitHubReleaseInfo {
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("AntigravityQuotaMonitor-Updater", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw AppUpdateError.invalidHTTPStatus(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(GitHubReleaseInfo.self, from: data)
        } catch {
            throw AppUpdateError.invalidReleasePayload
        }
    }

    func downloadArchive(from url: URL) async throws -> URL {
        var request = URLRequest(url: url)
        request.setValue("AntigravityQuotaMonitor-Updater", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 60

        let (tempURL, response): (URL, URLResponse)
        do {
            (tempURL, response) = try await URLSession.shared.download(for: request)
        } catch {
            throw AppUpdateError.downloadFailed(error.localizedDescription)
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw AppUpdateError.invalidHTTPStatus(httpResponse.statusCode)
        }

        let stagingZipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AntigravityQuotaMonitor-Update-\(UUID().uuidString).zip")
        do {
            if FileManager.default.fileExists(atPath: stagingZipURL.path) {
                try FileManager.default.removeItem(at: stagingZipURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: stagingZipURL)
            return stagingZipURL
        } catch {
            throw AppUpdateError.downloadFailed(error.localizedDescription)
        }
    }
}

nonisolated struct SystemAppUpdateInstaller: AppUpdateInstalling {
    private let cliRunner: any CLIProcessRunning

    init(cliRunner: any CLIProcessRunning = SystemCLIProcessRunner()) {
        self.cliRunner = cliRunner
    }

    func installAndRelaunch(
        archiveFileURL: URL,
        targetAppBundleURL: URL,
        currentProcessID: pid_t,
        terminateCurrentApp: @MainActor @Sendable () -> Void
    ) async throws {
        let fileManager = FileManager.default
        let stagingDir = fileManager.temporaryDirectory
            .appendingPathComponent("AntigravityQuotaMonitor-Stage-\(UUID().uuidString)", isDirectory: true)

        try fileManager.createDirectory(at: stagingDir, withIntermediateDirectories: true)

        let extractOutput = try await cliRunner.run(
            executablePath: "/usr/bin/ditto",
            arguments: ["-x", "-k", archiveFileURL.path, stagingDir.path],
            timeout: 30
        )
        try? fileManager.removeItem(at: archiveFileURL)

        guard extractOutput.exitCode == 0 else {
            try? fileManager.removeItem(at: stagingDir)
            throw AppUpdateError.extractionFailed("ditto exited with status \(extractOutput.exitCode)")
        }

        let expectedAppURL = stagingDir.appendingPathComponent("Antigravity Quota Monitor.app", isDirectory: true)
        let extractedAppURL: URL
        if fileManager.fileExists(atPath: expectedAppURL.path) {
            extractedAppURL = expectedAppURL
        } else if let discovered = try? fileManager.contentsOfDirectory(
            at: stagingDir,
            includingPropertiesForKeys: nil
        ).first(where: { $0.pathExtension == "app" }) {
            extractedAppURL = discovered
        } else {
            try? fileManager.removeItem(at: stagingDir)
            throw AppUpdateError.extractedAppBundleNotFound
        }

        _ = try? await cliRunner.run(
            executablePath: "/usr/bin/xattr",
            arguments: ["-cr", extractedAppURL.path],
            timeout: 10
        )

        let destinationURL = Self.resolveTargetDestinationURL(currentBundleURL: targetAppBundleURL)
        let script = """
        PID="$1"
        SRC_APP="$2"
        DEST_APP="$3"
        STAGE_DIR="$4"

        for _ in $(seq 1 50); do
            if ! kill -0 "$PID" 2>/dev/null; then
                break
            fi
            sleep 0.1
        done

        rm -rf "$DEST_APP"
        /usr/bin/ditto "$SRC_APP" "$DEST_APP"
        /usr/bin/xattr -cr "$DEST_APP" 2>/dev/null || true
        rm -rf "$STAGE_DIR"
        /usr/bin/open -n "$DEST_APP"
        """

        let updaterProcess = Process()
        updaterProcess.executableURL = URL(fileURLWithPath: "/bin/sh")
        updaterProcess.arguments = [
            "-c",
            script,
            "antigravity-updater",
            String(currentProcessID),
            extractedAppURL.path,
            destinationURL.path,
            stagingDir.path
        ]
        updaterProcess.standardInput = FileHandle.nullDevice
        updaterProcess.standardOutput = FileHandle.nullDevice
        updaterProcess.standardError = FileHandle.nullDevice

        do {
            try updaterProcess.run()
        } catch {
            try? fileManager.removeItem(at: stagingDir)
            throw AppUpdateError.installLaunchFailed(error.localizedDescription)
        }

        await terminateCurrentApp()
    }

    static func resolveTargetDestinationURL(currentBundleURL: URL) -> URL {
        let standardized = currentBundleURL.standardizedFileURL
        if standardized.pathExtension == "app" {
            return standardized
        }
        return URL(fileURLWithPath: "/Applications/Antigravity Quota Monitor.app")
    }
}

nonisolated enum AppUpdateState: Sendable, Equatable {
    case idle
    case checking
    case upToDate(version: String)
    case updateAvailable(GitHubReleaseInfo)
    case updating(status: String)
    case failed(message: String)
}

@MainActor
@Observable
final class AppUpdateManager {
    private let networkClient: any AppUpdateNetworking
    private let installer: any AppUpdateInstalling
    private let releaseEndpointURL: URL
    private let currentBundleURL: URL
    private let currentProcessID: pid_t
    private let terminateApp: @MainActor @Sendable () -> Void

    let currentVersion: String
    private(set) var state: AppUpdateState = .idle

    init(
        currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.0",
        currentBundleURL: URL = Bundle.main.bundleURL,
        currentProcessID: pid_t = ProcessInfo.processInfo.processIdentifier,
        releaseEndpointURL: URL = SystemAppUpdateNetworkClient.latestReleaseURL,
        networkClient: any AppUpdateNetworking = SystemAppUpdateNetworkClient(),
        installer: any AppUpdateInstalling = SystemAppUpdateInstaller(),
        terminateApp: @escaping @MainActor @Sendable () -> Void = { NSApplication.shared.terminate(nil) }
    ) {
        self.currentVersion = SemanticVersion.normalize(currentVersion)
        self.currentBundleURL = currentBundleURL
        self.currentProcessID = currentProcessID
        self.releaseEndpointURL = releaseEndpointURL
        self.networkClient = networkClient
        self.installer = installer
        self.terminateApp = terminateApp
    }

    var currentDisplayVersion: String {
        "v\(currentVersion)"
    }

    func checkForUpdates() async {
        switch state {
        case .checking, .updating:
            return
        default:
            break
        }

        state = .checking
        do {
            let latestRelease = try await networkClient.fetchLatestRelease(from: releaseEndpointURL)
            if SemanticVersion.isRemoteNewer(
                remote: latestRelease.normalizedVersion,
                current: currentVersion
            ) {
                state = .updateAvailable(latestRelease)
            } else {
                state = .upToDate(version: currentDisplayVersion)
            }
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    func performUpdate(to release: GitHubReleaseInfo) async {
        if case .updating = state {
            return
        }

        guard let asset = release.preferredZipAsset else {
            state = .failed(message: AppUpdateError.missingDownloadAsset.localizedDescription)
            return
        }

        state = .updating(status: "Downloading \(release.displayTag)…")
        do {
            let archiveURL = try await networkClient.downloadArchive(from: asset.browserDownloadURL)
            state = .updating(status: "Installing \(release.displayTag)…")
            try await installer.installAndRelaunch(
                archiveFileURL: archiveURL,
                targetAppBundleURL: currentBundleURL,
                currentProcessID: currentProcessID,
                terminateCurrentApp: terminateApp
            )
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }
}
