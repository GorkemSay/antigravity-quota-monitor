import Foundation
import Observation

nonisolated protocol ModelDetecting: Sendable {
    func detectActiveModel() async -> ModelDetectionResult
    func requestAccessibilityPermissionPrompt()
}

nonisolated protocol QuotaFetching: Sendable {
    func fetchQuota() async throws -> QuotaSnapshot
    func updateCustomExecutablePath(_ path: String?) async
}

extension XcodeModelDetector: ModelDetecting {}
extension AntigravityQuotaProvider: QuotaFetching {}

nonisolated struct QuotaErrorInfo: Sendable, Equatable {
    let message: String
    let occurredAt: Date
}

nonisolated enum ResolvedQuotaState: Sendable, Equatable {
    case idle
    case loading
    case active(
        model: DetectedModel,
        group: QuotaGroup,
        limitingBucket: QuotaBucket
    )
    case unmatchedModel(
        model: DetectedModel,
        availableGroupNames: [String]
    )
    case modelDetectionIssue(ModelDetectionResult)
    case error(message: String)
}

@MainActor
@Observable
final class QuotaManager {
    private let modelDetector: any ModelDetecting
    private let quotaProvider: any QuotaFetching
    private let now: @Sendable () -> Date
    private let explicitStaleThreshold: TimeInterval?
    private let modelPollInterval: TimeInterval

    private(set) var refreshInterval: TimeInterval
    private(set) var modelDetection: ModelDetectionResult?
    private(set) var snapshot: QuotaSnapshot?
    private(set) var lastSuccessfulUpdate: Date?
    private(set) var lastError: QuotaErrorInfo?
    private(set) var isRefreshing = false
    private(set) var isPollingActive = false

    private var quotaPollingTask: Task<Void, Never>?
    private var modelPollingTask: Task<Void, Never>?

    init(
        modelDetector: any ModelDetecting = XcodeModelDetector(),
        quotaProvider: any QuotaFetching = AntigravityQuotaProvider(),
        refreshInterval: TimeInterval = 180,
        modelPollInterval: TimeInterval = 15,
        staleThreshold: TimeInterval? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.modelDetector = modelDetector
        self.quotaProvider = quotaProvider
        self.refreshInterval = max(refreshInterval, 0.01)
        self.modelPollInterval = max(modelPollInterval, 0.01)
        self.explicitStaleThreshold = staleThreshold
        self.now = now
    }

    var effectiveStaleThreshold: TimeInterval {
        if let explicitStaleThreshold {
            return explicitStaleThreshold
        }
        return max(refreshInterval * 2.5, 600)
    }

    var isStale: Bool {
        guard let lastSuccessfulUpdate else { return false }
        if lastError != nil {
            return true
        }
        return now().timeIntervalSince(lastSuccessfulUpdate) > effectiveStaleThreshold
    }

    var resolvedState: ResolvedQuotaState {
        if isRefreshing && snapshot == nil && modelDetection == nil {
            return .loading
        }

        if let detection = modelDetection {
            switch detection {
            case .detected(let model):
                if let snapshot {
                    switch ModelQuotaMapper.map(model: model, in: snapshot) {
                    case .matched(let group, let bucket):
                        return .active(model: model, group: group, limitingBucket: bucket)
                    case .matchedEmptyGroup:
                        return .unmatchedModel(model: model, availableGroupNames: snapshot.groups.map(\.name))
                    case .unmatched(_, let available):
                        return .unmatchedModel(model: model, availableGroupNames: available)
                    }
                } else if let lastError {
                    return .error(message: lastError.message)
                } else {
                    return .loading
                }

            case .permissionRequired, .xcodeNotRunning, .modelNotFound:
                return .modelDetectionIssue(detection)
            }
        }

        if let lastError {
            return .error(message: lastError.message)
        }

        return .idle
    }

    var menuBarDisplayText: String? {
        guard case .active(let model, _, let bucket) = resolvedState else {
            return nil
        }
        return "\(model.shortAbbreviation) \(bucket.remainingPercent)%"
    }

    func startBackgroundPolling() {
        guard !isPollingActive else { return }
        isPollingActive = true
        scheduleQuotaPollingTask()
        scheduleModelPollingTask()
    }

    func stopBackgroundPolling() {
        isPollingActive = false
        quotaPollingTask?.cancel()
        quotaPollingTask = nil
        modelPollingTask?.cancel()
        modelPollingTask = nil
    }

    func updateRefreshInterval(_ newInterval: TimeInterval) {
        let sanitized = max(newInterval, 0.01)
        guard abs(sanitized - refreshInterval) > 0.0001 else { return }
        refreshInterval = sanitized
        if isPollingActive {
            scheduleQuotaPollingTask()
        }
    }

    func updateCustomCLIPath(_ path: String?) async {
        await quotaProvider.updateCustomExecutablePath(path)
    }

    func refreshAll() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        async let detected = modelDetector.detectActiveModel()
        do {
            let fetchedSnapshot = try await quotaProvider.fetchQuota()
            let detectedResult = await detected
            modelDetection = detectedResult
            snapshot = fetchedSnapshot
            lastSuccessfulUpdate = now()
            lastError = nil
        } catch {
            let detectedResult = await detected
            modelDetection = detectedResult
            lastError = QuotaErrorInfo(
                message: error.localizedDescription,
                occurredAt: now()
            )
        }
    }

    func refreshActiveModelOnly() async {
        modelDetection = await modelDetector.detectActiveModel()
    }

    func requestAccessibilityPermission() {
        modelDetector.requestAccessibilityPermissionPrompt()
    }

    private func scheduleQuotaPollingTask() {
        quotaPollingTask?.cancel()
        let interval = refreshInterval
        quotaPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled, let self else { break }
                await self.refreshAll()
            }
        }
    }

    private func scheduleModelPollingTask() {
        modelPollingTask?.cancel()
        let interval = modelPollInterval
        modelPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled, let self else { break }
                if !self.isRefreshing {
                    await self.refreshActiveModelOnly()
                }
            }
        }
    }
}
