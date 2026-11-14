import Foundation
import os

nonisolated struct CLIProcessOutput: Sendable, Equatable {
    let exitCode: Int32
    let stdout: Data
    let stderr: Data
}

nonisolated protocol CLIProcessRunning: Sendable {
    func run(
        executablePath: String,
        arguments: [String],
        timeout: TimeInterval
    ) async throws -> CLIProcessOutput
}

nonisolated struct SystemCLIProcessRunner: CLIProcessRunning {
    private struct ExecutionState: Sendable {
        var finished = false
        var didTimeout = false
        var stdoutData = Data()
        var stderrData = Data()
    }

    func run(
        executablePath: String,
        arguments: [String],
        timeout: TimeInterval
    ) async throws -> CLIProcessOutput {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.standardInput = FileHandle.nullDevice

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let state = OSAllocatedUnfairLock(initialState: ExecutionState())
            let readGroup = DispatchGroup()

            readGroup.enter()
            DispatchQueue.global(qos: .utility).async {
                let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                state.withLock { $0.stdoutData = data }
                readGroup.leave()
            }

            readGroup.enter()
            DispatchQueue.global(qos: .utility).async {
                let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                state.withLock { $0.stderrData = data }
                readGroup.leave()
            }

            let timeoutWorkItem = DispatchWorkItem {
                let shouldTerminate = state.withLock { current -> Bool in
                    guard !current.finished else { return false }
                    current.didTimeout = true
                    return true
                }

                if shouldTerminate, process.isRunning {
                    process.terminate()
                }
            }

            process.terminationHandler = { terminatedProcess in
                timeoutWorkItem.cancel()
                readGroup.notify(queue: DispatchQueue.global(qos: .utility)) {
                    let result = state.withLock { current -> Result<CLIProcessOutput, QuotaProviderError>? in
                        guard !current.finished else { return nil }
                        current.finished = true
                        if current.didTimeout {
                            return .failure(.executionTimedOut(seconds: timeout))
                        }
                        return .success(CLIProcessOutput(
                            exitCode: terminatedProcess.terminationStatus,
                            stdout: current.stdoutData,
                            stderr: current.stderrData
                        ))
                    }

                    if let result {
                        continuation.resume(with: result)
                    }
                }
            }

            do {
                try process.run()
                DispatchQueue.global(qos: .utility).asyncAfter(
                    deadline: .now() + timeout,
                    execute: timeoutWorkItem
                )
            } catch {
                timeoutWorkItem.cancel()
                let shouldResume = state.withLock { current -> Bool in
                    guard !current.finished else { return false }
                    current.finished = true
                    return true
                }
                if shouldResume {
                    continuation.resume(throwing: QuotaProviderError.launchFailed(error.localizedDescription))
                }
            }
        }
    }
}

nonisolated struct QuotaCLIResponseParser {
    private struct CLIResponseDTO: Decodable {
        let status: String?
        let command: CommandDTO?
    }

    private struct CommandDTO: Decodable {
        let name: String?
        let data: CommandDataDTO?
    }

    private struct CommandDataDTO: Decodable {
        let description: String?
        let groups: [GroupDTO]?
    }

    private struct GroupDTO: Decodable {
        let name: String
        let description: String?
        let buckets: [BucketDTO]
    }

    private struct BucketDTO: Decodable {
        let id: String
        let name: String
        let description: String?
        let window: String
        let remainingFraction: Double
        let resetTime: String?

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case description
            case window
            case remainingFraction = "remaining_fraction"
            case resetTime = "reset_time"
        }
    }

    static func parse(data: Data, fetchedAt: Date = Date()) throws -> QuotaSnapshot {
        guard !data.isEmpty,
              let rawText = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !rawText.isEmpty else {
            throw QuotaProviderError.emptyOutput
        }

        let candidates = extractBalancedJSONObjects(from: rawText)
        guard !candidates.isEmpty else {
            throw QuotaProviderError.invalidJSONPayload
        }

        let decoder = JSONDecoder()
        var decodedResponse: CLIResponseDTO?

        for candidate in candidates {
            guard let candidateData = candidate.data(using: .utf8),
                  let response = try? decoder.decode(CLIResponseDTO.self, from: candidateData) else {
                continue
            }
            if response.command != nil || response.status != nil {
                decodedResponse = response
                break
            }
        }

        guard let response = decodedResponse else {
            throw QuotaProviderError.invalidJSONPayload
        }

        if let status = response.status,
           status.caseInsensitiveCompare("SUCCESS") != .orderedSame {
            throw QuotaProviderError.invalidStatus(status)
        }

        guard let command = response.command else {
            throw QuotaProviderError.unexpectedCommandName(nil)
        }

        guard command.name?.caseInsensitiveCompare("usage") == .orderedSame else {
            throw QuotaProviderError.unexpectedCommandName(command.name)
        }

        guard let rawGroups = command.data?.groups, !rawGroups.isEmpty else {
            throw QuotaProviderError.missingQuotaGroups
        }

        let groups = rawGroups.map { groupDTO in
            let buckets = groupDTO.buckets.map { bucketDTO in
                QuotaBucket(
                    id: bucketDTO.id,
                    name: bucketDTO.name,
                    description: bucketDTO.description,
                    window: bucketDTO.window,
                    remainingFraction: bucketDTO.remainingFraction,
                    resetTime: parseISO8601Date(bucketDTO.resetTime),
                    rawResetTime: bucketDTO.resetTime
                )
            }
            return QuotaGroup(
                name: groupDTO.name,
                description: groupDTO.description,
                buckets: buckets
            )
        }

        return QuotaSnapshot(
            fetchedAt: fetchedAt,
            overviewDescription: command.data?.description,
            groups: groups
        )
    }

    static func extractBalancedJSONObjects(from text: String) -> [String] {
        var objects: [String] = []
        var currentStart: String.Index?
        var depth = 0
        var inString = false
        var isEscaped = false

        var index = text.startIndex
        while index < text.endIndex {
            let char = text[index]

            if currentStart == nil {
                if char == "{" {
                    currentStart = index
                    depth = 1
                    inString = false
                    isEscaped = false
                }
            } else {
                if inString {
                    if isEscaped {
                        isEscaped = false
                    } else if char == "\\" {
                        isEscaped = true
                    } else if char == "\"" {
                        inString = false
                    }
                } else {
                    if char == "\"" {
                        inString = true
                    } else if char == "{" {
                        depth += 1
                    } else if char == "}" {
                        depth -= 1
                        if depth == 0, let start = currentStart {
                            let end = text.index(after: index)
                            objects.append(String(text[start..<end]))
                            currentStart = nil
                        }
                    }
                }
            }

            index = text.index(after: index)
        }

        return objects
    }

    private static func parseISO8601Date(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }

        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        if let date = standard.date(from: value) {
            return date
        }

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value)
    }
}

actor AntigravityQuotaProvider {
    typealias ExecutableChecker = @Sendable (String) -> Bool

    private let processRunner: any CLIProcessRunning
    private let isExecutableFile: ExecutableChecker
    private let homeDirectoryPath: String
    private let environmentPATH: String?
    private let timeoutSeconds: TimeInterval
    private var customExecutablePath: String?
    private var inFlightTask: Task<QuotaSnapshot, Error>?

    init(
        processRunner: any CLIProcessRunning = SystemCLIProcessRunner(),
        isExecutableFile: @escaping ExecutableChecker = { FileManager.default.isExecutableFile(atPath: $0) },
        homeDirectoryPath: String = FileManager.default.homeDirectoryForCurrentUser.path,
        environmentPATH: String? = ProcessInfo.processInfo.environment["PATH"],
        customExecutablePath: String? = nil,
        timeoutSeconds: TimeInterval = 20
    ) {
        self.processRunner = processRunner
        self.isExecutableFile = isExecutableFile
        self.homeDirectoryPath = homeDirectoryPath
        self.environmentPATH = environmentPATH
        self.customExecutablePath = customExecutablePath
        self.timeoutSeconds = timeoutSeconds
    }

    func updateCustomExecutablePath(_ path: String?) {
        customExecutablePath = path
    }

    func resolveExecutablePath() throws -> String {
        if let custom = customExecutablePath?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty {
            let expanded = expandTilde(in: custom)
            if isExecutableFile(expanded) {
                return expanded
            }
            throw QuotaProviderError.executableNotFound(searchedPaths: [expanded])
        }

        let candidates = defaultExecutableCandidates()
        if let found = candidates.first(where: isExecutableFile) {
            return found
        }
        throw QuotaProviderError.executableNotFound(searchedPaths: candidates)
    }

    func fetchQuota() async throws -> QuotaSnapshot {
        if let existing = inFlightTask {
            return try await existing.value
        }

        let task = Task<QuotaSnapshot, Error> {
            let executablePath = try resolveExecutablePath()
            let output = try await processRunner.run(
                executablePath: executablePath,
                arguments: ["-p", "/usage", "--output-format", "json"],
                timeout: timeoutSeconds
            )

            guard output.exitCode == 0 else {
                throw QuotaProviderError.nonZeroExit(code: output.exitCode)
            }

            return try QuotaCLIResponseParser.parse(data: output.stdout)
        }

        inFlightTask = task
        defer { inFlightTask = nil }

        return try await task.value
    }

    private func defaultExecutableCandidates() -> [String] {
        var seen = Set<String>()
        var candidates: [String] = []

        func appendUnique(_ path: String) {
            let normalized = (path as NSString).standardizingPath
            if !normalized.isEmpty, seen.insert(normalized).inserted {
                candidates.append(normalized)
            }
        }

        appendUnique("\(homeDirectoryPath)/.local/bin/agy")
        appendUnique("/opt/homebrew/bin/agy")
        appendUnique("/usr/local/bin/agy")
        appendUnique("/usr/bin/agy")

        if let environmentPATH {
            for dir in environmentPATH.split(separator: ":").map(String.init) where !dir.isEmpty {
                let expandedDir = expandTilde(in: dir)
                appendUnique((expandedDir as NSString).appendingPathComponent("agy"))
            }
        }

        return candidates
    }

    private func expandTilde(in path: String) -> String {
        if path == "~" {
            return homeDirectoryPath
        }
        if path.hasPrefix("~/") {
            return homeDirectoryPath + String(path.dropFirst())
        }
        return path
    }
}
