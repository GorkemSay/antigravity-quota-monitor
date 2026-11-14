import Foundation

nonisolated struct QuotaBucket: Sendable, Equatable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let window: String
    let remainingFraction: Double
    let resetTime: Date?
    let rawResetTime: String?

    var remainingPercent: Int {
        let clamped = min(max(remainingFraction, 0.0), 1.0)
        return Int((clamped * 100.0).rounded())
    }
}

nonisolated struct QuotaGroup: Sendable, Equatable, Identifiable {
    var id: String { name }
    let name: String
    let description: String?
    let buckets: [QuotaBucket]

    var lowestRemainingBucket: QuotaBucket? {
        buckets.min { lhs, rhs in
            if lhs.remainingFraction != rhs.remainingFraction {
                return lhs.remainingFraction < rhs.remainingFraction
            }
            return (lhs.resetTime ?? .distantFuture) < (rhs.resetTime ?? .distantFuture)
        }
    }
}

nonisolated struct QuotaSnapshot: Sendable, Equatable {
    let fetchedAt: Date
    let overviewDescription: String?
    let groups: [QuotaGroup]
}

nonisolated enum QuotaProviderError: Error, LocalizedError, Sendable, Equatable {
    case executableNotFound(searchedPaths: [String])
    case executionTimedOut(seconds: TimeInterval)
    case nonZeroExit(code: Int32)
    case invalidStatus(String)
    case unexpectedCommandName(String?)
    case emptyOutput
    case invalidJSONPayload
    case missingQuotaGroups
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let paths):
            if paths.isEmpty {
                return "Antigravity CLI (agy) executable was not found."
            }
            return "Antigravity CLI (agy) was not found. Checked: \(paths.joined(separator: ", "))."
        case .executionTimedOut(let seconds):
            return "Antigravity CLI quota request timed out after \(Int(seconds)) seconds."
        case .nonZeroExit(let code):
            return "Antigravity CLI exited with status code \(code)."
        case .invalidStatus(let status):
            return "Antigravity CLI returned status '\(status)'."
        case .unexpectedCommandName(let name):
            return "Unexpected CLI command response: '\(name ?? "none")'."
        case .emptyOutput:
            return "Antigravity CLI returned empty output."
        case .invalidJSONPayload:
            return "Could not extract valid JSON from Antigravity CLI output."
        case .missingQuotaGroups:
            return "Antigravity CLI response did not contain any quota groups."
        case .launchFailed(let message):
            return "Failed to launch Antigravity CLI: \(message)"
        }
    }
}
