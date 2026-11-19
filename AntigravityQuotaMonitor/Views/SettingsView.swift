import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: PreferencesStore
    let quotaManager: QuotaManager
    var updateManager = AppUpdateManager()
    let onDone: () -> Void

    @State private var cliPathDraft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    applyCLIPath()
                    updateManager.resetState()
                    onDone()
                }
                .controlSize(.small)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Refresh Interval")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("Refresh Interval", selection: $preferences.refreshIntervalMinutes) {
                    ForEach(PreferencesStore.allowedRefreshIntervals, id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: preferences.refreshIntervalMinutes) { _, newValue in
                    quotaManager.updateRefreshInterval(TimeInterval(newValue * 60))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Antigravity CLI Path (Optional)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    TextField("Auto (~/.local/bin/agy)", text: $cliPathDraft)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .onSubmit {
                            applyCLIPath()
                        }

                    if !cliPathDraft.isEmpty {
                        Button("Clear") {
                            cliPathDraft = ""
                            applyCLIPath()
                        }
                        .controlSize(.small)
                    }
                }

                Text("Leave empty to auto-detect agy from ~/.local/bin, Homebrew, or PATH.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Launch at Login", isOn: Binding(
                    get: { preferences.launchAtLoginEnabled },
                    set: { preferences.setLaunchAtLogin($0) }
                ))
                .font(.subheadline)

                if let error = preferences.launchAtLoginError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Accessibility")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if quotaManager.modelDetection == .permissionRequired {
                        Button("Grant Access") {
                            quotaManager.requestAccessibilityPermission()
                        }
                        .controlSize(.small)
                    } else {
                        Label("Configured", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                updateSection
            }
        }
        .onAppear {
            cliPathDraft = preferences.customCLIPath
            preferences.refreshLaunchAtLoginStatus()
            updateManager.resetState()
        }
        .onDisappear {
            updateManager.resetState()
        }
    }

    @ViewBuilder
    private var updateSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Updates (\(updateManager.currentDisplayVersion))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                switch updateManager.state {
                case .idle:
                    Button("Check for Updates") {
                        Task { await updateManager.checkForUpdates() }
                    }
                    .controlSize(.small)

                case .checking:
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Checking…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                case .upToDate(let version):
                    Label("Up to date (\(version))", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)

                case .updateAvailable(let release):
                    HStack(spacing: 6) {
                        Text("\(release.displayTag) available!")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.orange)

                        Button("Update") {
                            Task { await updateManager.performUpdate(to: release) }
                        }
                        .controlSize(.small)
                    }

                case .updating(let status):
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.small)
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                case .failed:
                    Button("Check for Updates") {
                        Task { await updateManager.checkForUpdates() }
                    }
                    .controlSize(.small)
                }
            }

            if case .failed(let message) = updateManager.state {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func applyCLIPath() {
        let trimmed = cliPathDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != preferences.customCLIPath else { return }
        preferences.customCLIPath = trimmed
        Task {
            await quotaManager.updateCustomCLIPath(preferences.normalizedCustomCLIPath)
            await quotaManager.refreshAll()
        }
    }
}
