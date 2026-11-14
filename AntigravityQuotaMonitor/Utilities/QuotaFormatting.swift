import Foundation
import SwiftUI

nonisolated enum QuotaFormatting {
    static func formatResetTime(
        _ date: Date?,
        relativeTo now: Date = Date(),
        timeZone: TimeZone = .current,
        locale: Locale = Locale(identifier: "en_US_POSIX")
    ) -> String? {
        guard let date else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let timeFormatter = DateFormatter()
        timeFormatter.calendar = calendar
        timeFormatter.timeZone = timeZone
        timeFormatter.locale = locale
        timeFormatter.dateFormat = "HH:mm"
        let timePart = timeFormatter.string(from: date)

        let dateLabel: String
        if calendar.isDate(date, inSameDayAs: now) {
            dateLabel = "Today, \(timePart)"
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
                  calendar.isDate(date, inSameDayAs: tomorrow) {
            dateLabel = "Tomorrow, \(timePart)"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.calendar = calendar
            dayFormatter.timeZone = timeZone
            dayFormatter.locale = locale
            dayFormatter.dateFormat = "MMM d, HH:mm"
            dateLabel = dayFormatter.string(from: date)
        }

        let remaining = date.timeIntervalSince(now)
        if remaining > 60 {
            let relative = formatDuration(remaining)
            return "Resets \(dateLabel) (\(relative))"
        } else if remaining >= 0 {
            return "Resets \(dateLabel) (<1m)"
        } else {
            return "Reset window passed (\(dateLabel))"
        }
    }

    static func formatLastUpdated(
        _ date: Date?,
        timeZone: TimeZone = .current,
        locale: Locale = Locale(identifier: "en_US_POSIX")
    ) -> String {
        guard let date else { return "Not updated yet" }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.locale = locale
        formatter.dateFormat = "HH:mm"
        return "Updated \(formatter.string(from: date))"
    }

    static func formatDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = max(Int(interval / 60), 1)
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            return hours > 0 ? "in \(days)d \(hours)h" : "in \(days)d"
        }
        if hours > 0 {
            return minutes > 0 ? "in \(hours)h \(minutes)m" : "in \(hours)h"
        }
        return "in \(minutes)m"
    }

    static func tintColor(for remainingPercent: Int) -> Color {
        if remainingPercent >= 50 {
            return .green
        }
        if remainingPercent >= 20 {
            return .orange
        }
        return .red
    }
}
