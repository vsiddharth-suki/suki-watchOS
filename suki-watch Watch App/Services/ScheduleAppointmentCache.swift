import Foundation

struct ScheduleDaySnapshot {
    var appointments: [Appointment]
    var noteStatusByAppointmentId: [String: String]
}

/// In-memory schedule cache shared by Home and Schedule (survives navigation).
@MainActor
enum ScheduleAppointmentCache {
    private static var storage: [String: ScheduleDaySnapshot] = [:]

    static func dayKey(for date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: calendar.startOfDay(for: date))
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func snapshot(for date: Date) -> ScheduleDaySnapshot? {
        storage[dayKey(for: date)]
    }

    static func hasSnapshot(for date: Date) -> Bool {
        snapshot(for: date) != nil
    }

    static func store(
        appointments: [Appointment],
        noteStatusByAppointmentId: [String: String],
        for date: Date
    ) {
        storage[dayKey(for: date)] = ScheduleDaySnapshot(
            appointments: appointments,
            noteStatusByAppointmentId: noteStatusByAppointmentId
        )
    }

    static func clearAll() {
        storage = [:]
    }
}
