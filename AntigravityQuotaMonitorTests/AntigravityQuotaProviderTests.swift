import Foundation
import Testing
@testable import AntigravityQuotaMonitor

private actor MockCLIProcessRunner: CLIProcessRunning {
    typealias Handler = @Sendable (String, [String], TimeInterval) async throws -> CLIProcessOutput

    private let handler: Handler
    private(set) var callCount = 0
    private(set) var lastExecutablePath: String?
    private(set) var lastArguments: [String]?

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    func run(
        executablePath: String,
        arguments: [String],
        timeout: TimeInterval
    ) async throws -> CLIProcessOutput {
        callCount += 1
        lastExecutablePath = executablePath
        lastArguments = arguments
        return try await handler(executablePath, arguments, timeout)
    }
}

@Suite("QuotaCLIResponseParser")
struct QuotaCLIResponseParserTests {
    static let samplePayload = """
    {
      "conversation_id": "",
      "status": "SUCCESS",
      "response": "Gemini Models\\tWeekly Limit Remaining\\t96%\\t2026-11-21T11:53:53Z\\n",
      "duration_seconds": 0,
      "num_turns": 0,
      "command": {
        "name": "usage",
        "data": {
          "description": "Within each group, models share a weekly limit and a 5-hour limit.",
          "groups": [
            {
              "name": "Gemini Models",
              "description": "Models within this group: Gemini 4 Hydrogen, Gemini 3.8 Flash",
              "buckets": [
                {
                  "id": "gemini-weekly",
                  "name": "Weekly Limit Remaining",
                  "description": "You have used some of your weekly limit.",
                  "window": "weekly",
                  "remaining_fraction": 0.9595876336097717,
                  "reset_time": "2026-11-21T11:53:53Z"
                },
                {
                  "id": "gemini-5h",
                  "name": "Five Hour Limit Remaining",
                  "description": "You have used some of your 5-hour limit.",
                  "window": "5h",
                  "remaining_fraction": 0.9070035815238953,
                  "reset_time": "2026-11-14T16:53:53Z"
                }
              ]
            },
            {
              "name": "Claude and GPT models",
              "description": "Models within this group: Claude Opus 5.5, Claude Sonnet 5.5, GPT-OSS 120B",
              "buckets": [
                {
                  "id": "3p-weekly",
                  "name": "Weekly Limit Remaining",
                  "window": "weekly",
                  "remaining_fraction": 1,
                  "reset_time": "2026-11-21T14:16:55Z"
                },
                {
                  "id": "3p-5h",
                  "name": "Five Hour Limit Remaining",
                  "window": "5h",
                  "remaining_fraction": 1,
                  "reset_time": "2026-11-14T19:16:55.123Z"
                }
              ]
            },
            {
              "name": "Gemini 4 Argon",
              "description": "For paid Pro plans, Argon quota is separate.",
              "buckets": [
                {
                  "id": "gemini-argon-wtu-weekly",
                  "name": "Gemini 4 Argon Weekly Limit",
                  "description": "You have used some of your weekly limit.",
                  "window": "weekly",
                  "remaining_fraction": 0.9861493110656738,
                  "reset_time": "2026-11-21T12:59:21Z"
                }
              ]
            }
          ]
        }
      }
    }
    """

    @Test
    func parsesValidUsagePayloadAndComputesLowestBucket() throws {
        let fetchedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let data = Data(Self.samplePayload.utf8)

        let snapshot = try QuotaCLIResponseParser.parse(data: data, fetchedAt: fetchedAt)

        #expect(snapshot.fetchedAt == fetchedAt)
        #expect(snapshot.groups.count == 3)

        let gemini = snapshot.groups[0]
        #expect(gemini.name == "Gemini Models")
        #expect(gemini.buckets.count == 2)
        #expect(gemini.buckets[0].remainingPercent == 96)
        #expect(gemini.buckets[1].remainingPercent == 91)
        #expect(gemini.lowestRemainingBucket?.id == "gemini-5h")
        #expect(gemini.buckets[0].resetTime != nil)

        let claude = snapshot.groups[1]
        #expect(claude.buckets[0].description == nil)
        #expect(claude.buckets[0].remainingPercent == 100)
        #expect(claude.buckets[1].resetTime != nil)

        let argon = snapshot.groups[2]
        #expect(argon.buckets.count == 1)
        #expect(argon.buckets[0].remainingPercent == 99)
    }

    @Test
    func extractsJSONWrappedInLeadingLogsAndTrailingMarkdownWithBraces() throws {
        let wrapped = """
        [info] Starting usage lookup...
        {"note":"skip me"}
        {
          "status": "SUCCESS",
          "response": "Braces inside escaped string: \\"{test}\\" end",
          "command": {
            "name": "usage",
            "data": {
              "groups": [
                {
                  "name": "Gemini 4 Argon",
                  "buckets": [
                    {
                      "id": "gemini-argon-wtu-weekly",
                      "name": "Gemini 4 Argon Weekly Limit",
                      "window": "weekly",
                      "remaining_fraction": 0.99,
                      "reset_time": "2026-11-21T12:59:21Z"
                    }
                  ]
                }
              ]
            }
          }
        }
        ### Trailing Markdown Summary
        ```json
        { "ignored": true }
        ```
        """

        let snapshot = try QuotaCLIResponseParser.parse(data: Data(wrapped.utf8))
        #expect(snapshot.groups.count == 1)
        #expect(snapshot.groups[0].name == "Gemini 4 Argon")
        #expect(snapshot.groups[0].buckets[0].remainingPercent == 99)
    }

    @Test
    func rejectsEmptyInvalidAndNonSuccessResponses() {
        #expect(throws: QuotaProviderError.emptyOutput) {
            try QuotaCLIResponseParser.parse(data: Data("   \n ".utf8))
        }

        #expect(throws: QuotaProviderError.invalidJSONPayload) {
            try QuotaCLIResponseParser.parse(data: Data("not json at all {".utf8))
        }

        let failedStatus = """
        {"status":"ERROR","command":{"name":"usage","data":{"groups":[]}}}
        """
        #expect(throws: QuotaProviderError.invalidStatus("ERROR")) {
            try QuotaCLIResponseParser.parse(data: Data(failedStatus.utf8))
        }

        let emptyGroups = """
        {"status":"SUCCESS","command":{"name":"usage","data":{"groups":[]}}}
        """
        #expect(throws: QuotaProviderError.missingQuotaGroups) {
            try QuotaCLIResponseParser.parse(data: Data(emptyGroups.utf8))
        }
    }
}

@Suite("AntigravityQuotaProvider")
struct AntigravityQuotaProviderTests {
    @Test
    func resolvesDefaultUserLocalBinExecutable() async throws {
        let runner = MockCLIProcessRunner { _, _, _ in
            CLIProcessOutput(
                exitCode: 0,
                stdout: Data(QuotaCLIResponseParserTests.samplePayload.utf8),
                stderr: Data()
            )
        }

        let provider = AntigravityQuotaProvider(
            processRunner: runner,
            isExecutableFile: { $0 == "/Users/tester/.local/bin/agy" },
            homeDirectoryPath: "/Users/tester",
            environmentPATH: "/usr/bin:/bin"
        )

        let snapshot = try await provider.fetchQuota()
        #expect(snapshot.groups.count == 3)
        #expect(await runner.lastExecutablePath == "/Users/tester/.local/bin/agy")
        #expect(await runner.lastArguments == ["-p", "/usage", "--output-format", "json"])
    }

    @Test
    func resolvesCustomTildeExpandedPathAndFailsWhenInvalid() async throws {
        let runner = MockCLIProcessRunner { _, _, _ in
            CLIProcessOutput(
                exitCode: 0,
                stdout: Data(QuotaCLIResponseParserTests.samplePayload.utf8),
                stderr: Data()
            )
        }

        let provider = AntigravityQuotaProvider(
            processRunner: runner,
            isExecutableFile: { $0 == "/Users/tester/custom/agy" },
            homeDirectoryPath: "/Users/tester",
            environmentPATH: nil,
            customExecutablePath: "~/custom/agy"
        )

        let path = try await provider.resolveExecutablePath()
        #expect(path == "/Users/tester/custom/agy")

        await provider.updateCustomExecutablePath("~/missing/agy")
        await #expect(throws: QuotaProviderError.executableNotFound(searchedPaths: ["/Users/tester/missing/agy"])) {
            _ = try await provider.resolveExecutablePath()
        }
    }

    @Test
    func surfacesNonZeroExitAndTimeoutErrors() async {
        let nonZeroRunner = MockCLIProcessRunner { _, _, _ in
            CLIProcessOutput(exitCode: 2, stdout: Data(), stderr: Data("err".utf8))
        }
        let providerA = AntigravityQuotaProvider(
            processRunner: nonZeroRunner,
            isExecutableFile: { $0 == "/opt/homebrew/bin/agy" },
            homeDirectoryPath: "/Users/tester"
        )

        await #expect(throws: QuotaProviderError.nonZeroExit(code: 2)) {
            _ = try await providerA.fetchQuota()
        }

        let timeoutRunner = MockCLIProcessRunner { _, _, timeout in
            throw QuotaProviderError.executionTimedOut(seconds: timeout)
        }
        let providerB = AntigravityQuotaProvider(
            processRunner: timeoutRunner,
            isExecutableFile: { $0 == "/opt/homebrew/bin/agy" },
            homeDirectoryPath: "/Users/tester",
            timeoutSeconds: 15
        )

        await #expect(throws: QuotaProviderError.executionTimedOut(seconds: 15)) {
            _ = try await providerB.fetchQuota()
        }
    }

    @Test
    func coalescesOverlappingFetchCalls() async throws {
        let runner = MockCLIProcessRunner { _, _, _ in
            try await Task.sleep(for: .milliseconds(80))
            return CLIProcessOutput(
                exitCode: 0,
                stdout: Data(QuotaCLIResponseParserTests.samplePayload.utf8),
                stderr: Data()
            )
        }

        let provider = AntigravityQuotaProvider(
            processRunner: runner,
            isExecutableFile: { $0 == "/Users/tester/.local/bin/agy" },
            homeDirectoryPath: "/Users/tester"
        )

        async let first = provider.fetchQuota()
        async let second = provider.fetchQuota()
        let (snapshotA, snapshotB) = try await (first, second)

        #expect(snapshotA == snapshotB)
        #expect(await runner.callCount == 1)
    }
}
