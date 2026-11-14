import Foundation
import Observation

nonisolated protocol ModelDetecting: Sendable {
    func detectActiveModel() async -> ModelDetectionResult
    func requestAccessibilityPermissionPrompt()
}

nonisolated protocol QuotaFetching: Sendable {
    func fetchQuota() async throws -> QuotaSnapshot
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
    private let staleThreshold: TimeInterval

    private(set) var modelDetection: ModelDetectionResult?
    private(set) var snapshot: QuotaSnapshot?
    private(set) var lastSuccessfulUpdate: Date?
    private(set) var lastError: QuotaErrorInfo?
    private(set) var isRefreshing = false

    init(
        modelDetector: any ModelDetecting = XcodeModelDetector(),
        quotaProvider: any QuotaFetching = AntigravityQuotaProvider(),
        staleThreshold: TimeInterval = 600,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.modelDetector = modelDetector
        self.quotaProvider = quotaProvider
        self.staleThreshold = staleThreshold
        self.now = now
    }

    var isStale: Bool {
        guard let lastSuccessfulUpdate else { return false }
        if lastError != nil {
            return true
        }
        return now().timeIntervalSince(lastSuccessfulUpdate) > staleThreshold
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
}
