import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: PreferencesStore
    let quotaManager: QuotaManager
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
        }
        .onAppear {
            cliPathDraft = preferences.customCLIPath
            preferences.refreshLaunchAtLoginStatus()
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
