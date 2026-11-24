import Foundation

nonisolated struct DetectedModel: Sendable, Equatable {
    let rawLabel: String
    let normalizedName: String
    let effortLevel: String?
    let shortAbbreviation: String

    static func parse(rawLabel: String) -> DetectedModel? {
        let trimmed = rawLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let (baseName, effort) = splitTrailingParenthetical(from: trimmed),
           isEffortOrModeDescriptor(effort) {
            let normalized = baseName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { return nil }

            return DetectedModel(
                rawLabel: trimmed,
                normalizedName: normalized,
                effortLevel: effort,
                shortAbbreviation: deriveAbbreviation(for: normalized, rawLabel: trimmed)
            )
        }

        // Reject labels that are purely a parenthetical like "(High)" with no model name
        if trimmed.hasPrefix("(") && trimmed.hasSuffix(")") {
            return nil
        }

        return DetectedModel(
            rawLabel: trimmed,
            normalizedName: trimmed,
            effortLevel: nil,
            shortAbbreviation: deriveAbbreviation(for: trimmed, rawLabel: trimmed)
        )
    }

    private static func isEffortOrModeDescriptor(_ candidate: String?) -> Bool {
        guard let candidate else { return true }
        let lower = candidate.lowercased()
        let knownEfforts: Set<String> = [
            "low",
            "medium",
            "high",
            "xhigh",
            "x-high",
            "extra high",
            "max",
            "thinking",
            "fast",
            "auto"
        ]
        return knownEfforts.contains(lower)
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

    private static func deriveAbbreviation(for normalizedName: String, rawLabel: String = "") -> String {
        let lower = normalizedName.lowercased()
        let rawLower = rawLabel.lowercased()

        if lower.contains("orchestrator") {
            if lower.contains("neon") || rawLower.contains("neon") { return "ON" }
            if lower.contains("carbon") || rawLower.contains("carbon") { return "OC" }
            if lower.contains("argon") || rawLower.contains("argon") { return "OA" }
            if lower.contains("hydrogen") || rawLower.contains("hydrogen") { return "OH" }
            if lower.contains("opus") || rawLower.contains("opus") { return "OO" }
            if lower.contains("sonnet") || rawLower.contains("sonnet") { return "OS" }
            return "OR"
        }
        if lower.contains("neon") { return "N" }
        if lower.contains("hydrogen") { return "H" }
        if lower.contains("argon") { return "A" }
        if lower.contains("carbon") { return "C" }
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

nonisolated enum ModelDetectionResult: Sendable, Equatable {
    case detected(DetectedModel)
    case permissionRequired
    case xcodeNotRunning
    case modelNotFound(inspectedNodes: Int)
}
