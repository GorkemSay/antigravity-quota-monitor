import SwiftUI

struct QuotaBucketRowView: View {
    let bucket: QuotaBucket
    let isCompact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(displayTitle)
                    .font(isCompact ? .caption : .subheadline)
                    .foregroundStyle(isCompact ? .secondary : .primary)
                    .lineLimit(1)

                Spacer()

                Text("\(bucket.remainingPercent)%")
                    .font((isCompact ? Font.caption : Font.subheadline).monospacedDigit().weight(.semibold))
                    .foregroundStyle(QuotaFormatting.tintColor(for: bucket.remainingPercent))
            }

            ProgressView(value: min(max(bucket.remainingFraction, 0), 1))
                .progressViewStyle(.linear)
                .tint(QuotaFormatting.tintColor(for: bucket.remainingPercent))
                .controlSize(.small)

            if let resetText = QuotaFormatting.formatResetTime(bucket.resetTime) {
                Text(resetText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var displayTitle: String {
        switch bucket.window.lowercased() {
        case "5h":
            return "5-Hour Limit"
        case "weekly":
            return "Weekly Limit"
        default:
            return bucket.name
        }
    }
}
