import Foundation

enum DateRangeFormatter {
    private static let utcRangeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(abbreviation: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return f
    }()

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
