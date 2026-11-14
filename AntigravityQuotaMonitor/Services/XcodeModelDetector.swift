import AppKit
import ApplicationServices
import Foundation

protocol AccessibilityTreeReading: Sendable {
    associatedtype Node

    func isProcessTrusted() -> Bool
    func requestAccessibilityPermission()
    func runningXcodeProcessIDs() -> [pid_t]
    func rootWindows(for pid: pid_t) -> [Node]
    func role(of node: Node) -> String
    func help(of node: Node) -> String
    func candidateLabels(of node: Node) -> [String]
    func children(of node: Node) -> [Node]
}

struct LiveAccessibilityTreeReader: AccessibilityTreeReading {
    typealias Node = AXUIElement

    static let xcodeBundleIdentifier = "com.apple.dt.Xcode"

    func isProcessTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: kCFBooleanTrue!] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func runningXcodeProcessIDs() -> [pid_t] {
        let apps = NSRunningApplication.runningApplications(
            withBundleIdentifier: Self.xcodeBundleIdentifier
        )
        let sorted = apps.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive {
                return lhs.isActive && !rhs.isActive
            }
            return lhs.processIdentifier < rhs.processIdentifier
        }
        return sorted.map(\.processIdentifier)
    }

    func rootWindows(for pid: pid_t) -> [AXUIElement] {
        let appElement = AXUIElementCreateApplication(pid)
        var roots: [AXUIElement] = []

        func appendUnique(_ candidate: AXUIElement?) {
            guard let candidate else { return }
            if !roots.contains(where: { CFEqual($0, candidate) }) {
                roots.append(candidate)
            }
        }

        appendUnique(elementAttribute(appElement, kAXFocusedWindowAttribute))
        appendUnique(elementAttribute(appElement, kAXMainWindowAttribute))

        if let windows = attribute(appElement, kAXWindowsAttribute) as? [AnyObject] {
            for item in windows {
                if CFGetTypeID(item) == AXUIElementGetTypeID() {
                    let windowElement = unsafeBitCast(item, to: AXUIElement.self)
                    appendUnique(windowElement)
                }
            }
        }

        if roots.isEmpty {
            roots.append(appElement)
        }
        return roots
    }

    func role(of node: AXUIElement) -> String {
        textAttribute(node, kAXRoleAttribute)
    }

    func help(of node: AXUIElement) -> String {
        textAttribute(node, kAXHelpAttribute)
    }

    func candidateLabels(of node: AXUIElement) -> [String] {
        [
            textAttribute(node, kAXDescriptionAttribute),
            textAttribute(node, kAXTitleAttribute),
            textAttribute(node, kAXValueAttribute),
            textAttribute(node, "AXLabel")
        ]
    }

    func children(of node: AXUIElement) -> [AXUIElement] {
        guard let rawChildren = attribute(node, kAXChildrenAttribute) as? [AnyObject] else {
            return []
        }
        var result: [AXUIElement] = []
        result.reserveCapacity(rawChildren.count)
        for item in rawChildren where CFGetTypeID(item) == AXUIElementGetTypeID() {
            result.append(unsafeBitCast(item, to: AXUIElement.self))
        }
        return result
    }

    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        return status == .success ? value : nil
    }

    private func textAttribute(_ element: AXUIElement, _ name: String) -> String {
        attribute(element, name) as? String ?? ""
    }

    private func elementAttribute(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let raw = attribute(element, name),
              CFGetTypeID(raw) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeBitCast(raw, to: AXUIElement.self)
    }
}

final class XcodeModelDetector<Reader: AccessibilityTreeReading>: Sendable {
    private let reader: Reader
    private let maxDepth: Int
    private let nodeLimitPerRoot: Int

    nonisolated init(
        reader: Reader,
        maxDepth: Int = 40,
        nodeLimitPerRoot: Int = 6000
    ) {
        self.reader = reader
        self.maxDepth = maxDepth
        self.nodeLimitPerRoot = nodeLimitPerRoot
    }

    nonisolated func detectActiveModel() async -> ModelDetectionResult {
        await Task.detached(priority: .utility) { [reader, maxDepth, nodeLimitPerRoot] in
            Self.detectSynchronously(
                reader: reader,
                maxDepth: maxDepth,
                nodeLimitPerRoot: nodeLimitPerRoot
            )
        }.value
    }

    nonisolated func detectActiveModelSync() -> ModelDetectionResult {
        Self.detectSynchronously(
            reader: reader,
            maxDepth: maxDepth,
            nodeLimitPerRoot: nodeLimitPerRoot
        )
    }

    nonisolated func isAccessibilityTrusted() -> Bool {
        reader.isProcessTrusted()
    }

    nonisolated func requestAccessibilityPermissionPrompt() {
        reader.requestAccessibilityPermission()
    }

    private nonisolated static func detectSynchronously(
        reader: Reader,
        maxDepth: Int,
        nodeLimitPerRoot: Int
    ) -> ModelDetectionResult {
        guard reader.isProcessTrusted() else {
            return .permissionRequired
        }

        let pids = reader.runningXcodeProcessIDs()
        guard !pids.isEmpty else {
            return .xcodeNotRunning
        }

        var totalInspected = 0

        for pid in pids {
            let roots = reader.rootWindows(for: pid)
            for root in roots {
                var inspectedInRoot = 0
                if let rawLabel = findModelLabel(
                    in: root,
                    depth: 0,
                    inspected: &inspectedInRoot,
                    maxDepth: maxDepth,
                    nodeLimit: nodeLimitPerRoot,
                    reader: reader
                ),
                   let parsed = DetectedModel.parse(rawLabel: rawLabel) {
                    return .detected(parsed)
                }
                totalInspected += inspectedInRoot
            }
        }

        return .modelNotFound(inspectedNodes: totalInspected)
    }

    private nonisolated static func findModelLabel(
        in node: Reader.Node,
        depth: Int,
        inspected: inout Int,
        maxDepth: Int,
        nodeLimit: Int,
        reader: Reader
    ) -> String? {
        guard depth < maxDepth, inspected < nodeLimit else {
            return nil
        }
        inspected += 1

        if reader.role(of: node) == "AXMenuButton" {
            let help = reader.help(of: node)
            if help.caseInsensitiveCompare("Model") == .orderedSame {
                let candidates = reader.candidateLabels(of: node)
                if let label = candidates
                    .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
                    .first(where: { !$0.isEmpty }) {
                    return label
                }
            }
        }

        for child in reader.children(of: node) {
            if let found = findModelLabel(
                in: child,
                depth: depth + 1,
                inspected: &inspected,
                maxDepth: maxDepth,
                nodeLimit: nodeLimit,
                reader: reader
            ) {
                return found
            }
        }

        return nil
    }
}

extension XcodeModelDetector where Reader == LiveAccessibilityTreeReader {
    nonisolated convenience init() {
        self.init(reader: LiveAccessibilityTreeReader())
    }
}
