import Foundation

final class ScheduleService {
    private let api: APIClient

    init(api: APIClient = APIClient()) {
        self.api = api
    }

    func refreshEMRAppointments(from: String, to: String, forceRefresh: Bool) async throws {
        let body = RefreshEMRAppointmentBody(
            toDate: to,
            fromDate: from,
            forceRefresh: forceRefresh,
            emrAccessToken: nil
        )
        let data = try JSONEncoder().encode(body)
        let descriptor = APIRequestDescriptor(
            host: .v2,
            path: "/emr/emr-appointments-refresh",
            method: "POST",
            body: data
        )
        try await api.send(descriptor)
    }

    func fetchAppointments(from: String, to: String) async throws -> [Appointment] {
        let descriptor = APIRequestDescriptor(
            host: .v2,
            path: "/patients/schedule",
            method: "GET",
            query: [
                "startsAtRangeBeginning": from,
                "startsAtRangeEnd": to,
                "filterInternalAppointments": "true"
            ]
        )
        let response = try await api.send(descriptor, as: AppointmentsResponse.self)
        return response.appointments
    }

    func loadSchedule(for date: Date, forceEMRRefresh: Bool, belongsToEMR: Bool = SessionStore.shared.belongsToEMR) async throws -> [Appointment] {
        let range = DateRangeFormatter.dayRange(for: date)
        if belongsToEMR {
            try await refreshEMRAppointments(from: range.start, to: range.end, forceRefresh: forceEMRRefresh)
        }
        return try await fetchAppointments(from: range.start, to: range.end)
    }

    /// iOS `APIRequest.fetchNoteStatus(..., forScreen: .schedule)` — keyed by appointment id.
    func fetchNoteStatus(appointmentIds: [String]) async throws -> [String: String] {
        guard !appointmentIds.isEmpty else { return [:] }
        let queryItems = appointmentIds.map { URLQueryItem(name: "appointmentIds[]", value: $0) }
        let descriptor = APIRequestDescriptor(
            host: .v2,
            path: "/notes/status",
            method: "GET",
            queryItems: queryItems
        )
        let response = try await api.send(descriptor, as: NoteStatusMapResponse.self)
        var map: [String: String] = [:]
        for (key, value) in response.noteStatusMap {
            map[key] = value ?? ""
        }
        return map
    }
}
