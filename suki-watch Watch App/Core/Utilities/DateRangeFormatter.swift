import Foundation

enum DateRangeFormatter {
    private static let utcRangeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(abbreviation: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return f
    }()

    static func parseISO8601(_ iso: String) -> Date? {
        let parsers: [ISO8601DateFormatter] = {
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            return [withFraction, plain]
        }()
        if let parsed = parsers.compactMap({ $0.date(from: iso) }).first {
            return parsed
        }
        return utcRangeFormatter.date(from: iso)
    }

    static func dayRange(for date: Date) -> (start: String, end: String) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = startOfDay.addingTimeInterval(24 * 60 * 60 - 1)
        return (utcRangeFormatter.string(from: startOfDay), utcRangeFormatter.string(from: endOfDay))
    }

    static func appointmentTimeLabel(iso: String?) -> String {
        guard let iso, !iso.isEmpty else { return "—" }
        let parsers: [ISO8601DateFormatter] = {
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            return [withFraction, plain]
        }()
        guard let parsed = parsers.compactMap({ $0.date(from: iso) }).first else { return iso }
        let out = DateFormatter()
        out.timeStyle = .short
        out.dateStyle = .none
        return out.string(from: parsed)
    }

    static func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    /// iOS `Date.convertISOtoMonthDayYear` for patient profile note rows.
    /// iOS `Date.formatRecordingDuration` for ambient recording UI.
    static func formatRecordingDuration(seconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        if seconds >= 3600 {
            formatter.allowedUnits = [.hour, .minute, .second]
        } else if seconds < 60 {
            formatter.allowedUnits = [.second]
            let formattedSeconds = formatter.string(from: TimeInterval(seconds)) ?? "00"
            return "00:" + formattedSeconds
        } else {
            formatter.allowedUnits = [.minute, .second]
        }
        return formatter.string(from: TimeInterval(seconds)) ?? "00:00"
    }

    static func ambientSessionTimestamp(iso: String?) -> String {
        guard let iso, !iso.isEmpty,
              let date = NoteDateClassification.parseCreatedAt(iso)
        else { return "Session" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func monthDayYear(iso: String?) -> String {
        guard let iso, !iso.isEmpty,
              let date = NoteDateClassification.parseCreatedAt(iso)
        else { return "Unavailable" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: date)
    }

    static func noteServiceDateLabel(iso: String?) -> String {
        guard let iso, !iso.isEmpty else { return "—" }
        let parsers: [ISO8601DateFormatter] = {
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            return [withFraction, plain]
        }()
        if let parsed = parsers.compactMap({ $0.date(from: iso) }).first {
            return shortDate(parsed)
        }
        return appointmentTimeLabel(iso: iso)
    }
}
