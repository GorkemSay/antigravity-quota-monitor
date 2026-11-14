import Foundation
import Testing
@testable import AntigravityQuotaMonitor

private final class MutableClock: @unchecked Sendable {
    var current: Date

    init(_ initial: Date) {
        self.current = initial
    }
}

private actor StubModelDetector: ModelDetecting {
    private var nextResult: ModelDetectionResult

    init(initial: ModelDetectionResult) {
        self.nextResult = initial
    }

    func setResult(_ result: ModelDetectionResult) {
        nextResult = result
    }

    func detectActiveModel() async -> ModelDetectionResult {
        nextResult
    }

    nonisolated func requestAccessibilityPermissionPrompt() {}
}

private actor StubQuotaProvider: QuotaFetching {
    private var nextOutcome: Result<QuotaSnapshot, Error>

    init(initial: Result<QuotaSnapshot, Error>) {
        self.nextOutcome = initial
    }

    func setOutcome(_ outcome: Result<QuotaSnapshot, Error>) {
        nextOutcome = outcome
    }

    func fetchQuota() async throws -> QuotaSnapshot {
        try nextOutcome.get()
    }
}

@Suite("QuotaManager")
struct QuotaManagerTests {
    @Test
    @MainActor
    func refreshesModelAndQuotaSuccessfully() async throws {
        let clock = MutableClock(Date(timeIntervalSince1970: 1_700_000_000))
        let hydrogen = try #require(DetectedModel.parse(rawLabel: "Gemini 4 Hydrogen (High)"))
        let detector = StubModelDetector(initial: .detected(hydrogen))
        let provider = StubQuotaProvider(initial: .success(ModelQuotaMapperTests.sampleSnapshot))

        let manager = QuotaManager(
            modelDetector: detector,
            quotaProvider: provider,
            staleThreshold: 300,
            now: { clock.current }
        )

        await manager.refreshAll()

        #expect(manager.menuBarDisplayText == "H 90%")
        #expect(manager.isStale == false)
        #expect(manager.lastError == nil)
        #expect(manager.lastSuccessfulUpdate == clock.current)
    }

    @Test
    @MainActor
    func updatesDisplayImmediatelyWhenActiveModelChanges() async throws {
        let clock = MutableClock(Date(timeIntervalSince1970: 1_700_000_000))
        let hydrogen = try #require(DetectedModel.parse(rawLabel: "Gemini 4 Hydrogen (High)"))
        let argon = try #require(DetectedModel.parse(rawLabel: "Gemini 4 Argon (Medium)"))
        let detector = StubModelDetector(initial: .detected(hydrogen))
        let provider = StubQuotaProvider(initial: .success(ModelQuotaMapperTests.sampleSnapshot))

        let manager = QuotaManager(
            modelDetector: detector,
            quotaProvider: provider,
            now: { clock.current }
        )

        await manager.refreshAll()
        #expect(manager.menuBarDisplayText == "H 90%")

        await detector.setResult(.detected(argon))
        await manager.refreshActiveModelOnly()
        #expect(manager.menuBarDisplayText == "A 99%")
    }

    @Test
    @MainActor
    func preservesLastValidSnapshotAndMarksStaleOnSubsequentError() async throws {
        let clock = MutableClock(Date(timeIntervalSince1970: 1_700_000_000))
        let hydrogen = try #require(DetectedModel.parse(rawLabel: "Gemini 4 Hydrogen (High)"))
        let detector = StubModelDetector(initial: .detected(hydrogen))
        let provider = StubQuotaProvider(initial: .success(ModelQuotaMapperTests.sampleSnapshot))

        let manager = QuotaManager(
            modelDetector: detector,
            quotaProvider: provider,
            staleThreshold: 300,
            now: { clock.current }
        )

        await manager.refreshAll()
        #expect(manager.menuBarDisplayText == "H 90%")
        #expect(manager.isStale == false)

        clock.current = clock.current.addingTimeInterval(60)
        await provider.setOutcome(.failure(QuotaProviderError.executionTimedOut(seconds: 20)))
        await manager.refreshAll()

        #expect(manager.snapshot != nil)
        #expect(manager.menuBarDisplayText == "H 90%")
        #expect(manager.isStale == true)
        #expect(manager.lastError?.message.contains("timed out") == true)
    }

    @Test
    @MainActor
    func marksDataStaleAfterThresholdWithoutError() async throws {
        let clock = MutableClock(Date(timeIntervalSince1970: 1_700_000_000))
        let hydrogen = try #require(DetectedModel.parse(rawLabel: "Gemini 4 Hydrogen (High)"))
        let detector = StubModelDetector(initial: .detected(hydrogen))
        let provider = StubQuotaProvider(initial: .success(ModelQuotaMapperTests.sampleSnapshot))

        let manager = QuotaManager(
            modelDetector: detector,
            quotaProvider: provider,
            staleThreshold: 300,
            now: { clock.current }
        )

        await manager.refreshAll()
        #expect(manager.isStale == false)

        clock.current = clock.current.addingTimeInterval(301)
        #expect(manager.isStale == true)
    }

    @Test
    @MainActor
    func surfacesErrorAndDetectionIssuesWithoutFakePercentages() async throws {
        let clock = MutableClock(Date(timeIntervalSince1970: 1_700_000_000))
        let hydrogen = try #require(DetectedModel.parse(rawLabel: "Gemini 4 Hydrogen (High)"))
        let detector = StubModelDetector(initial: .detected(hydrogen))
        let provider = StubQuotaProvider(initial: .failure(QuotaProviderError.executableNotFound(searchedPaths: [])))

        let manager = QuotaManager(
            modelDetector: detector,
            quotaProvider: provider,
            now: { clock.current }
        )

        await manager.refreshAll()
        #expect(manager.menuBarDisplayText == nil)
        if case .error = manager.resolvedState {
        } else {
            Issue.record("Expected .error state")
        }

        await provider.setOutcome(.success(ModelQuotaMapperTests.sampleSnapshot))
        await detector.setResult(.permissionRequired)
        await manager.refreshAll()
        #expect(manager.menuBarDisplayText == nil)
        #expect(manager.resolvedState == .modelDetectionIssue(.permissionRequired))

        let unknown = try #require(DetectedModel.parse(rawLabel: "Unknown Future Model"))
        await detector.setResult(.detected(unknown))
        await manager.refreshActiveModelOnly()
        #expect(manager.menuBarDisplayText == nil)
        if case .unmatchedModel(let model, _) = manager.resolvedState {
            #expect(model == unknown)
        } else {
            Issue.record("Expected .unmatchedModel state")
        }
    }
}
