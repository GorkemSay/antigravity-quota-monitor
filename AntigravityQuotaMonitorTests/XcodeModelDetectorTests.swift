import Foundation
import Testing
@testable import AntigravityQuotaMonitor

private struct MockNode: Sendable {
    let role: String
    let help: String
    let descriptionText: String
    let titleText: String
    let valueText: String
    let axLabelText: String
    let children: [MockNode]

    init(
        role: String = "AXGroup",
        help: String = "",
        descriptionText: String = "",
        titleText: String = "",
        valueText: String = "",
        axLabelText: String = "",
        children: [MockNode] = []
    ) {
        self.role = role
        self.help = help
        self.descriptionText = descriptionText
        self.titleText = titleText
        self.valueText = valueText
        self.axLabelText = axLabelText
        self.children = children
    }
}

private struct MockAccessibilityTreeReader: AccessibilityTreeReading {
    typealias Node = MockNode

    let trusted: Bool
    let pids: [pid_t]
    let windowsByPID: [pid_t: [MockNode]]

    func isProcessTrusted() -> Bool {
        trusted
    }

    func requestAccessibilityPermission() {}

    func runningXcodeProcessIDs() -> [pid_t] {
        pids
    }

    func rootWindows(for pid: pid_t) -> [MockNode] {
        windowsByPID[pid] ?? []
    }

    func role(of node: MockNode) -> String {
        node.role
    }

    func help(of node: MockNode) -> String {
        node.help
    }

    func candidateLabels(of node: MockNode) -> [String] {
        [node.descriptionText, node.titleText, node.valueText, node.axLabelText]
    }

    func children(of node: MockNode) -> [MockNode] {
        node.children
    }
}

@Suite("DetectedModel Parsing")
struct DetectedModelTests {
    @Test
    func parsesHydrogenWithEffort() {
        let model = DetectedModel.parse(rawLabel: "Gemini 4 Hydrogen (High)")
        #expect(model?.rawLabel == "Gemini 4 Hydrogen (High)")
        #expect(model?.normalizedName == "Gemini 4 Hydrogen")
        #expect(model?.effortLevel == "High")
        #expect(model?.shortAbbreviation == "H")
    }

    @Test
    func parsesArgonWithEffort() {
        let model = DetectedModel.parse(rawLabel: "Gemini 4 Argon (Medium)")
        #expect(model?.normalizedName == "Gemini 4 Argon")
        #expect(model?.effortLevel == "Medium")
        #expect(model?.shortAbbreviation == "A")
    }

    @Test
    func parsesKnownModelsWithoutEffort() {
        #expect(DetectedModel.parse(rawLabel: "Gemini 3.8 Flash")?.shortAbbreviation == "F")
        #expect(DetectedModel.parse(rawLabel: "Claude Opus 5.5 (Thinking)")?.shortAbbreviation == "O")
        #expect(DetectedModel.parse(rawLabel: "Claude Sonnet 5.5")?.shortAbbreviation == "S")
        #expect(DetectedModel.parse(rawLabel: "GPT-OSS 120B")?.shortAbbreviation == "G")
    }

    @Test
    func rejectsEmptyAndInvalidLabels() {
        #expect(DetectedModel.parse(rawLabel: "") == nil)
        #expect(DetectedModel.parse(rawLabel: "   \n  ") == nil)
        #expect(DetectedModel.parse(rawLabel: "(High)") == nil)
    }
}

@Suite("XcodeModelDetector")
struct XcodeModelDetectorTests {
    @Test
    func returnsPermissionRequiredWhenNotTrusted() async {
        let reader = MockAccessibilityTreeReader(trusted: false, pids: [123], windowsByPID: [:])
        let detector = XcodeModelDetector(reader: reader)

        let result = await detector.detectActiveModel()
        #expect(result == .permissionRequired)
    }

    @Test
    func returnsXcodeNotRunningWhenNoProcessFound() async {
        let reader = MockAccessibilityTreeReader(trusted: true, pids: [], windowsByPID: [:])
        let detector = XcodeModelDetector(reader: reader)

        let result = await detector.detectActiveModel()
        #expect(result == .xcodeNotRunning)
    }

    @Test
    func detectsModelInFocusedWindow() async {
        let modelButton = MockNode(
            role: "AXMenuButton",
            help: "model",
            descriptionText: "Gemini 4 Hydrogen (High)"
        )
        let window = MockNode(role: "AXWindow", children: [
            MockNode(role: "AXSplitGroup", children: [modelButton])
        ])
        let reader = MockAccessibilityTreeReader(
            trusted: true,
            pids: [42],
            windowsByPID: [42: [window]]
        )
        let detector = XcodeModelDetector(reader: reader)

        let result = await detector.detectActiveModel()
        #expect(result == .detected(DetectedModel(
            rawLabel: "Gemini 4 Hydrogen (High)",
            normalizedName: "Gemini 4 Hydrogen",
            effortLevel: "High",
            shortAbbreviation: "H"
        )))
    }

    @Test
    func fallsBackToSecondaryWindowAndTitleAttribute() async {
        let emptyWindow = MockNode(role: "AXWindow", children: [
            MockNode(role: "AXButton", help: "Run", titleText: "Run")
        ])
        let assistantWindow = MockNode(role: "AXWindow", children: [
            MockNode(role: "AXMenuButton", help: "Model", titleText: "Gemini 4 Argon (Medium)")
        ])
        let reader = MockAccessibilityTreeReader(
            trusted: true,
            pids: [99],
            windowsByPID: [99: [emptyWindow, assistantWindow]]
        )
        let detector = XcodeModelDetector(reader: reader)

        let result = await detector.detectActiveModel()
        #expect(result == .detected(DetectedModel(
            rawLabel: "Gemini 4 Argon (Medium)",
            normalizedName: "Gemini 4 Argon",
            effortLevel: "Medium",
            shortAbbreviation: "A"
        )))
    }

    @Test
    func returnsModelNotFoundWhenNoConversationIsOpen() async {
        let window = MockNode(role: "AXWindow", children: [
            MockNode(role: "AXGroup", children: [
                MockNode(role: "AXMenuButton", help: "Scheme", descriptionText: "AntigravityQuotaMonitor")
            ])
        ])
        let reader = MockAccessibilityTreeReader(
            trusted: true,
            pids: [55],
            windowsByPID: [55: [window]]
        )
        let detector = XcodeModelDetector(reader: reader)

        let result = await detector.detectActiveModel()
        #expect(result == .modelNotFound(inspectedNodes: 3))
    }

    @Test
    func respectsNodeLimitGuard() async {
        let leaf = MockNode(role: "AXMenuButton", help: "Model", descriptionText: "Gemini 4 Hydrogen (High)")
        let parent = MockNode(role: "AXGroup", children: [
            MockNode(role: "AXGroup", children: [leaf])
        ])
        let reader = MockAccessibilityTreeReader(
            trusted: true,
            pids: [77],
            windowsByPID: [77: [parent]]
        )
        let detector = XcodeModelDetector(reader: reader, maxDepth: 40, nodeLimitPerRoot: 2)

        let result = await detector.detectActiveModel()
        #expect(result == .modelNotFound(inspectedNodes: 2))
    }
}
