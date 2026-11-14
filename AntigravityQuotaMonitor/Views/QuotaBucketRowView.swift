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
                    .foregroundStyle(tintColor)
            }

            ProgressView(value: clampedFraction)
                .progressViewStyle(QuotaLinearProgressStyle(tint: tintColor))

            if let resetText = QuotaFormatting.formatResetTime(bucket.resetTime) {
                Text(resetText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var clampedFraction: Double {
        min(max(bucket.remainingFraction, 0), 1)
    }

    private var tintColor: Color {
        QuotaFormatting.tintColor(for: bucket.remainingPercent)
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

private struct QuotaLinearProgressStyle: ProgressViewStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        let fraction = min(max(configuration.fractionCompleted ?? 0, 0), 1)
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.14))

                Capsule()
                    .fill(tint)
                    .frame(width: max(fraction > 0 ? 5 : 0, proxy.size.width * fraction))
            }
        }
        .frame(height: 5)
    }
}
