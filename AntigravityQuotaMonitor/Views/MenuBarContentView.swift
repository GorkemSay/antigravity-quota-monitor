import AppKit
import SwiftUI

struct MenuBarContentView: View {
    let quotaManager: QuotaManager
    let preferences: PreferencesStore

    @State private var showingSettings = false

    var body: some View {
        Group {
            if showingSettings {
                SettingsView(
                    preferences: preferences,
                    quotaManager: quotaManager,
                    onDone: { showingSettings = false }
                )
            } else {
                quotaOverviewContent
            }
        }
        .padding(14)
        .frame(width: 340)
        .task {
            if quotaManager.snapshot == nil && !quotaManager.isRefreshing {
                await quotaManager.refreshAll()
            } else {
                await quotaManager.refreshActiveModelOnly()
            }
        }
    }

    private var quotaOverviewContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection

            if let lastError = quotaManager.lastError {
                errorBanner(message: lastError.message)
            }

            activeStateSection

            if let snapshot = quotaManager.snapshot {
                otherGroupsSection(snapshot: snapshot)
            }

            Divider()

            footerSection
        }
    }

    private var headerSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "atom")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(AntigravityQuotaMonitorApp.appDisplayName)
                .font(.headline)

            Spacer()

            if quotaManager.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            } else if quotaManager.isStale {
                Text("Stale")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.15), in: Capsule())
            }

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.subheadline)
            }
            .buttonStyle(.borderless)
            .help("Settings")
            .accessibilityLabel("Settings")
        }
    }

    private func errorBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.top, 1)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var activeStateSection: some View {
        switch quotaManager.resolvedState {
        case .idle, .loading:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading active model and quota…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

        case .active(let model, let group, let limitingBucket):
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    Text(model.shortAbbreviation)
                        .font(.caption.bold())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.rawLabel)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(group.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text("\(limitingBucket.remainingPercent)%")
                        .font(.title3.monospacedDigit().weight(.bold))
                        .foregroundStyle(QuotaFormatting.tintColor(for: limitingBucket.remainingPercent))
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(group.buckets) { bucket in
                        QuotaBucketRowView(bucket: bucket, isCompact: false)
                    }
                }
            }
            .padding(10)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))

        case .unmatchedModel(let model, _):
            VStack(alignment: .leading, spacing: 4) {
                Text("Active Model: \(model.rawLabel)")
                    .font(.subheadline.weight(.medium))
                Text("No matching quota group was found in the current CLI output.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))

        case .modelDetectionIssue(let detection):
            modelDetectionIssueCard(for: detection)

        case .error:
            EmptyView()
        }
    }

    @ViewBuilder
    private func modelDetectionIssueCard(for detection: ModelDetectionResult) -> some View {
        switch detection {
        case .permissionRequired:
            VStack(alignment: .leading, spacing: 8) {
                Text("Accessibility permission is required to detect the active model in Xcode.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Grant Accessibility Access") {
                    quotaManager.requestAccessibilityPermission()
                }
                .controlSize(.small)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))

        case .xcodeNotRunning:
            Label("Xcode is not running.", systemImage: "hammer")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .modelNotFound(let inspectedNodes):
            Text("No Antigravity model selector found in Xcode (\(inspectedNodes) elements inspected). Open an assistant conversation to match automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

        case .detected:
            EmptyView()
        }
    }

    @ViewBuilder
    private func otherGroupsSection(snapshot: QuotaSnapshot) -> some View {
        let activeGroupName: String? = {
            if case .active(_, let group, _) = quotaManager.resolvedState {
                return group.name
            }
            return nil
        }()

        let groupsToShow = snapshot.groups.filter { $0.name != activeGroupName }
        if !groupsToShow.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(activeGroupName == nil ? "Quota Groups" : "Other Quota Groups")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(groupsToShow) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.name)
                            .font(.caption.weight(.medium))

                        ForEach(group.buckets) { bucket in
                            QuotaBucketRowView(bucket: bucket, isCompact: true)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var footerSection: some View {
        HStack(spacing: 8) {
            Text(QuotaFormatting.formatLastUpdated(quotaManager.lastSuccessfulUpdate))
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Refresh") {
                Task { await quotaManager.refreshAll() }
            }
            .keyboardShortcut("r")
            .disabled(quotaManager.isRefreshing)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

#Preview {
    MenuBarContentView(
        quotaManager: QuotaManager(),
        preferences: PreferencesStore()
    )
}
