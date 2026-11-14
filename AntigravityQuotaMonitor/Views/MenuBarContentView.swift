import AppKit
import SwiftUI

struct MenuBarContentView: View {
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

            Text("Model detection and quota monitoring will be connected in upcoming milestones.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack {
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(14)
        .frame(width: 280)
    }
}

#Preview {
    MenuBarContentView()
}
