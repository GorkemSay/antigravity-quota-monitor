import Foundation
import Testing
@testable import AntigravityQuotaMonitor

@Suite("ModelQuotaMapper")
struct ModelQuotaMapperTests {
    static let sampleSnapshot = QuotaSnapshot(
        fetchedAt: Date(timeIntervalSince1970: 1_700_000_000),
        overviewDescription: nil,
        groups: [
            QuotaGroup(
                name: "Gemini Models",
                description: "Models within this group: Gemini 4 Neon, Gemini 4 Hydrogen, Orchestrator (Neon), Gemini 3.8 Flash",
                buckets: [
                    QuotaBucket(
                        id: "gemini-weekly",
                        name: "Weekly Limit Remaining",
                        description: nil,
                        window: "weekly",
                        remainingFraction: 0.96,
                        resetTime: nil,
                        rawResetTime: nil
                    ),
                    QuotaBucket(
                        id: "gemini-5h",
                        name: "Five Hour Limit Remaining",
                        description: nil,
                        window: "5h",
                        remainingFraction: 0.90,
                        resetTime: nil,
                        rawResetTime: nil
                    )
                ]
            ),
            QuotaGroup(
                name: "Claude and GPT models",
                description: "Models within this group: Claude Opus 5.5, Claude Sonnet 5.5, GPT-OSS 120B",
                buckets: [
                    QuotaBucket(
                        id: "3p-weekly",
                        name: "Weekly Limit Remaining",
                        description: nil,
                        window: "weekly",
                        remainingFraction: 1.0,
                        resetTime: nil,
                        rawResetTime: nil
                    ),
                    QuotaBucket(
                        id: "3p-5h",
                        name: "Five Hour Limit Remaining",
                        description: nil,
                        window: "5h",
                        remainingFraction: 0.85,
                        resetTime: nil,
                        rawResetTime: nil
                    )
                ]
            ),
            QuotaGroup(
                name: "Gemini 4 Argon",
                description: "For paid Pro plans, Argon quota is separate.",
                buckets: [
                    QuotaBucket(
                        id: "gemini-argon-wtu-weekly",
                        name: "Gemini 4 Argon Weekly Limit",
                        description: nil,
                        window: "weekly",
                        remainingFraction: 0.99,
                        resetTime: nil,
                        rawResetTime: nil
                    )
                ]
            )
        ]
    )

    @Test
    func mapsHydrogenAndFlashToGeminiModelsLowestBucket() throws {
        let hydrogen = try #require(DetectedModel.parse(rawLabel: "Gemini 4 Hydrogen (High)"))
        let flash = try #require(DetectedModel.parse(rawLabel: "Gemini 3.8 Flash"))

        let hydrogenMapping = ModelQuotaMapper.map(model: hydrogen, in: Self.sampleSnapshot)
        guard case .matched(let hGroup, let hBucket) = hydrogenMapping else {
            Issue.record("Expected matched group for Hydrogen")
            return
        }
        #expect(hGroup.name == "Gemini Models")
        #expect(hBucket.id == "gemini-5h")
        #expect(hBucket.remainingPercent == 90)

        let flashMapping = ModelQuotaMapper.map(model: flash, in: Self.sampleSnapshot)
        guard case .matched(let fGroup, let fBucket) = flashMapping else {
            Issue.record("Expected matched group for Flash")
            return
        }
        #expect(fGroup.name == "Gemini Models")
        #expect(fBucket.id == "gemini-5h")
    }

    @Test
    func mapsArgonToSeparateArgonGroupWithoutFallingIntoGeminiModels() throws {
        let argon = try #require(DetectedModel.parse(rawLabel: "Gemini 4 Argon (Medium)"))

        let mapping = ModelQuotaMapper.map(model: argon, in: Self.sampleSnapshot)
        guard case .matched(let group, let bucket) = mapping else {
            Issue.record("Expected matched group for Argon")
            return
        }
        #expect(group.name == "Gemini 4 Argon")
        #expect(bucket.id == "gemini-argon-wtu-weekly")
        #expect(bucket.remainingPercent == 99)

        let orchestratorArgon = try #require(DetectedModel.parse(rawLabel: "Orchestrator (Argon)"))
        let orchestratorArgonMapping = ModelQuotaMapper.map(model: orchestratorArgon, in: Self.sampleSnapshot)
        guard case .matched(let oaGroup, let oaBucket) = orchestratorArgonMapping else {
            Issue.record("Expected matched group for Orchestrator (Argon)")
            return
        }
        #expect(oaGroup.name == "Gemini 4 Argon")
        #expect(oaBucket.id == "gemini-argon-wtu-weekly")
    }

    @Test
    func mapsNeonCarbonAndOrchestratorVariantsCorrectly() throws {
        for label in [
            "Gemini 4 Neon (High)",
            "Gemini 4 Neon (XHigh)",
            "Orchestrator (Neon)",
            "Gemini 4 Carbon (High)",
            "Orchestrator (Carbon)"
        ] {
            let model = try #require(DetectedModel.parse(rawLabel: label))
            let mapping = ModelQuotaMapper.map(model: model, in: Self.sampleSnapshot)
            guard case .matched(let group, let bucket) = mapping else {
                Issue.record("Expected matched group for \(label)")
                return
            }
            #expect(group.name == "Gemini Models")
            #expect(bucket.id == "gemini-5h")
            #expect(bucket.remainingPercent == 90)
        }
    }

    @Test
    func mapsClaudeAndGPTModelsToThirdPartyGroup() throws {
        for label in ["Claude Opus 5.5 (Thinking)", "Claude Sonnet 5.5", "GPT-OSS 120B"] {
            let model = try #require(DetectedModel.parse(rawLabel: label))
            let mapping = ModelQuotaMapper.map(model: model, in: Self.sampleSnapshot)
            guard case .matched(let group, let bucket) = mapping else {
                Issue.record("Expected matched group for \(label)")
                return
            }
            #expect(group.name == "Claude and GPT models")
            #expect(bucket.id == "3p-5h")
            #expect(bucket.remainingPercent == 85)
        }
    }

    @Test
    func mapsViaDescriptionListWhenNewModelAppears() throws {
        let customSnapshot = QuotaSnapshot(
            fetchedAt: Date(),
            overviewDescription: nil,
            groups: [
                QuotaGroup(
                    name: "Experimental Pool",
                    description: "Models within this group: Nova Alpha, Orion Beta",
                    buckets: [
                        QuotaBucket(
                            id: "exp-weekly",
                            name: "Weekly",
                            description: nil,
                            window: "weekly",
                            remainingFraction: 0.72,
                            resetTime: nil,
                            rawResetTime: nil
                        )
                    ]
                )
            ]
        )

        let orion = try #require(DetectedModel.parse(rawLabel: "Orion Beta (High)"))
        let mapping = ModelQuotaMapper.map(model: orion, in: customSnapshot)
        guard case .matched(let group, let bucket) = mapping else {
            Issue.record("Expected description-based match")
            return
        }
        #expect(group.name == "Experimental Pool")
        #expect(bucket.remainingPercent == 72)
    }

    @Test
    func returnsUnmatchedForUnknownModelInsteadOfGuessing() throws {
        let unknown = try #require(DetectedModel.parse(rawLabel: "Llama 4 Maverick"))
        let mapping = ModelQuotaMapper.map(model: unknown, in: Self.sampleSnapshot)

        #expect(mapping == .unmatched(
            model: unknown,
            availableGroupNames: ["Gemini Models", "Claude and GPT models", "Gemini 4 Argon"]
        ))
    }

    @Test
    func findsLowestBucketAcrossAllGroups() {
        let lowest = ModelQuotaMapper.lowestGroup(in: Self.sampleSnapshot)
        #expect(lowest?.group.name == "Claude and GPT models")
        #expect(lowest?.bucket.id == "3p-5h")
        #expect(lowest?.bucket.remainingPercent == 85)
    }
}
