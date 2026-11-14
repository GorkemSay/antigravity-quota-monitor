import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @State private var detectionResult: ModelDetectionResult?
    @State private var isChecking = false

    private let detector = XcodeModelDetector()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "atom")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(AntigravityQuotaMonitorApp.appDisplayName)
                    .font(.headline)
            }

            Divider()

            modelStatusSection

            Divider()

            HStack {
                Button("Check Model") {
                    Task { await refreshModel() }
                }
                .disabled(isChecking)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(14)
        .frame(width: 300)
        .task {
            await refreshModel()
        }
    }

    @ViewBuilder
    private var modelStatusSection: some View {
        switch detectionResult {
        case .none:
            Text("Checking Xcode active model…")
                .font(.subheadline)
                .foregroundStyle(.secondary)

        case .detected(let model):
            VStack(alignment: .leading, spacing: 4) {
                Text("Active Xcode Model")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text(model.shortAbbreviation)
                        .font(.caption.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                    Text(model.rawLabel)
                        .font(.subheadline.weight(.medium))
                }
                Text("Quota retrieval will be connected in Milestone 3–4.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .permissionRequired:
            VStack(alignment: .leading, spacing: 8) {
                Text("Accessibility permission is required to read Xcode's active model selector.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Grant Accessibility Access") {
                    detector.requestAccessibilityPermissionPrompt()
                }
            }

        case .xcodeNotRunning:
            Text("Xcode is not running.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

        case .modelNotFound(let inspectedNodes):
            Text("No Antigravity model selector found in Xcode (\(inspectedNodes) elements inspected). Open an assistant conversation and try again.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func refreshModel() async {
        isChecking = true
        let result = await detector.detectActiveModel()
        detectionResult = result
        isChecking = false
    }
}

#Preview {
    MenuBarContentView()
}
