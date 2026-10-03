import Foundation

enum NoteDateClassification {
    private static let isoParsers: [ISO8601DateFormatter] = {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return [withFraction, plain]
    }()

    static func parseCreatedAt(_ iso: String?) -> Date? {
        guard let iso, !iso.isEmpty else { return nil }
        if let parsed = isoParsers.compactMap({ $0.date(from: iso) }).first {
            return parsed
        }
        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.timeZone = TimeZone(secondsFromGMT: 0)
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        if let parsed = fallback.date(from: iso) { return parsed }
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return fallback.date(from: iso)
    }

    /// Whether the ISO timestamp falls on today (GMT), matching iOS home recent-notes filtering.
    static func isToday(iso: String?) -> Bool {
        guard let date = parseCreatedAt(iso) else { return false }
        return isTodayGMT(date)
    }

    static func mostRecentDate(createdAt: String?, updatedAt: String?) -> Date {
        let created = parseCreatedAt(createdAt) ?? .distantPast
        let updated = parseCreatedAt(updatedAt) ?? .distantPast
        return max(created, updated)
    }

    /// Matches iOS patient profile: today, future, or within the prior five calendar days.
    static func isCurrentSectionNote(createdAt: String?) -> Bool {
        guard let date = parseCreatedAt(createdAt) else { return false }
        if date > Date() { return true }
        if isTodayGMT(date) { return true }
        return isWithinFiveDaysPriorToToday(date)
    }

    private static func isTodayGMT(_ date: Date) -> Bool {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "GMT") ?? TimeZone(secondsFromGMT: 0)!
        return calendar.isDateInToday(date)
    }

    private static func isWithinFiveDaysPriorToToday(_ date: Date) -> Bool {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "GMT") ?? TimeZone(secondsFromGMT: 0)!
        let startOfToday = calendar.startOfDay(for: Date())
        guard let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: startOfToday) else {
            return false
        }
        return date < startOfToday && date >= fiveDaysAgo
    }
}
