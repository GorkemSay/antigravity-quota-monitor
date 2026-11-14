import Foundation
import Testing
@testable import AntigravityQuotaMonitor

@Suite("QuotaFormatting")
struct QuotaFormattingTests {
    @Test
    func formatsSameDayResetTimeInTargetTimeZone() throws {
        var calendar = Calendar(identifier: .gregorian)
        let istanbul = try #require(TimeZone(identifier: "Europe/Istanbul"))
        calendar.timeZone = istanbul

        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 17, minute: 0)))
        let reset = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 19, minute: 36)))

        let formatted = QuotaFormatting.formatResetTime(reset, relativeTo: now, timeZone: istanbul)
        #expect(formatted == "Resets Today, 19:36 (in 2h 36m)")
    }

    @Test
    func formatsFutureDayResetTimeWithDaysAndHours() throws {
        var calendar = Calendar(identifier: .gregorian)
        let utc = try #require(TimeZone(identifier: "UTC"))
        calendar.timeZone = utc

        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 14, minute: 0)))
        let reset = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: 11, minute: 53)))

        let formatted = QuotaFormatting.formatResetTime(reset, relativeTo: now, timeZone: utc)
        #expect(formatted == "Resets Nov 21, 11:53 (in 6d 21h)")
    }

    @Test
    func formatsLastUpdatedTimeOrFallback() throws {
        var calendar = Calendar(identifier: .gregorian)
        let utc = try #require(TimeZone(identifier: "UTC"))
        calendar.timeZone = utc

        let updated = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 9, minute: 5)))
        #expect(QuotaFormatting.formatLastUpdated(updated, timeZone: utc) == "Updated 09:05")
        #expect(QuotaFormatting.formatLastUpdated(nil, timeZone: utc) == "Not updated yet")
    }
}
