import Foundation

nonisolated enum ModelMappingResult: Sendable, Equatable {
    case matched(group: QuotaGroup, limitingBucket: QuotaBucket)
    case matchedEmptyGroup(group: QuotaGroup)
    case unmatched(model: DetectedModel, availableGroupNames: [String])
}

nonisolated struct ModelQuotaMapper: Sendable {
    static func map(model: DetectedModel, in snapshot: QuotaSnapshot) -> ModelMappingResult {
        let groups = snapshot.groups
        guard !groups.isEmpty else {
            return .unmatched(model: model, availableGroupNames: [])
        }

        let normalizedModel = normalize(model.normalizedName)

        // 1. Exact group name match (e.g. "Gemini 4 Argon" -> group "Gemini 4 Argon")
        if let exactGroup = groups.first(where: { normalize($0.name) == normalizedModel }) {
            return result(for: exactGroup)
        }

        // 2. Explicit model list in group description (e.g. "Models within this group: Gemini 4 Hydrogen, Gemini 3.8 Flash")
        if let describedGroup = groups.first(where: { groupContainsModel($0, normalizedModel: normalizedModel) }) {
            return result(for: describedGroup)
        }

        // 3. Family/model-specific fallback rules when description is absent or changed
        if normalizedModel.contains("argon") {
            if let argonGroup = groups.first(where: { normalize($0.name).contains("argon") }) {
                return result(for: argonGroup)
            }
            return .unmatched(model: model, availableGroupNames: groups.map(\.name))
        }

        if normalizedModel.contains("neon")
            || normalizedModel.contains("hydrogen")
            || normalizedModel.contains("carbon")
            || normalizedModel.contains("orchestrator")
            || normalizedModel.contains("flash")
            || normalizedModel.contains("gemini") {
            if let geminiGroup = groups.first(where: {
                let name = normalize($0.name)
                return name.contains("gemini") && !name.contains("argon")
            }) {
                return result(for: geminiGroup)
            }
        }

        if normalizedModel.contains("claude")
            || normalizedModel.contains("opus")
            || normalizedModel.contains("sonnet")
            || normalizedModel.contains("gpt") {
            if let thirdPartyGroup = groups.first(where: {
                let name = normalize($0.name)
                return name.contains("claude") || name.contains("gpt")
            }) {
                return result(for: thirdPartyGroup)
            }
        }

        return .unmatched(model: model, availableGroupNames: groups.map(\.name))
    }

    static func lowestGroup(in snapshot: QuotaSnapshot) -> (group: QuotaGroup, bucket: QuotaBucket)? {
        snapshot.groups
            .compactMap { group -> (QuotaGroup, QuotaBucket)? in
                guard let bucket = group.lowestRemainingBucket else { return nil }
                return (group, bucket)
            }
            .min { lhs, rhs in
                if lhs.1.remainingFraction != rhs.1.remainingFraction {
                    return lhs.1.remainingFraction < rhs.1.remainingFraction
                }
                return (lhs.1.resetTime ?? .distantFuture) < (rhs.1.resetTime ?? .distantFuture)
            }
    }

    private static func result(for group: QuotaGroup) -> ModelMappingResult {
        if let bucket = group.lowestRemainingBucket {
            return .matched(group: group, limitingBucket: bucket)
        }
        return .matchedEmptyGroup(group: group)
    }

    private static func groupContainsModel(_ group: QuotaGroup, normalizedModel: String) -> Bool {
        guard let description = group.description else { return false }

        let listedText: String
        if let colonRange = description.range(of: ":") {
            listedText = String(description[colonRange.upperBound...])
        } else {
            listedText = description
        }

        let listedModels = listedText
            .split(separator: ",")
            .map { normalize(String($0)) }
            .filter { !$0.isEmpty }

        if listedModels.contains(normalizedModel) {
            return true
        }

        return listedModels.contains { candidate in
            normalizedModel.contains(candidate) || candidate.contains(normalizedModel)
        }
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}
