import Foundation

struct DetectedModel: Sendable, Equatable {
    let rawLabel: String
    let normalizedName: String
    let effortLevel: String?
    let shortAbbreviation: String

    static func parse(rawLabel: String) -> DetectedModel? {
        let trimmed = rawLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard let (baseName, effort) = splitTrailingParenthetical(from: trimmed) else {
            return nil
        }

        let normalized = baseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        return DetectedModel(
            rawLabel: trimmed,
            normalizedName: normalized,
            effortLevel: effort,
            shortAbbreviation: deriveAbbreviation(for: normalized)
        )
    }

    private static func splitTrailingParenthetical(from value: String) -> (String, String?)? {
        guard value.hasSuffix(")"),
              let openParen = value.lastIndex(of: "(") else {
            return (value, nil)
        }

        if openParen == value.startIndex {
            return nil
        }

        let afterOpen = value.index(after: openParen)
        let beforeClose = value.index(before: value.endIndex)
        guard afterOpen <= beforeClose else {
            return (value, nil)
        }

        let candidateEffort = String(value[afterOpen..<beforeClose])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = String(value[..<openParen])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !prefix.isEmpty, !candidateEffort.isEmpty else {
            return nil
        }

        return (prefix, candidateEffort)
    }

    private static func deriveAbbreviation(for normalizedName: String) -> String {
        let lower = normalizedName.lowercased()
        if lower.contains("hydrogen") { return "H" }
        if lower.contains("argon") { return "A" }
        if lower.contains("flash") { return "F" }
        if lower.contains("opus") { return "O" }
        if lower.contains("sonnet") { return "S" }
        if lower.contains("gpt") { return "G" }

        if let firstLetter = normalizedName.first(where: { $0.isLetter || $0.isNumber }) {
            return String(firstLetter).uppercased()
        }
        return "?"
    }
}

enum ModelDetectionResult: Sendable, Equatable {
    case detected(DetectedModel)
    case permissionRequired
    case xcodeNotRunning
    case modelNotFound(inspectedNodes: Int)
}
