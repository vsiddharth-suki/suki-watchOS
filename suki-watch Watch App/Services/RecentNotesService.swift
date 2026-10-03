import Foundation

/// iOS home “Recent Notes” card: unfinished compositions + in-progress ambient sessions.
final class RecentNotesService {
    private let api: APIClient
    private let sessionStore: SessionStore

    init(api: APIClient = APIClient(), sessionStore: SessionStore = .shared) {
        self.api = api
        self.sessionStore = sessionStore
    }

    /// Same cap as iOS home (`combinedNotesSorted.prefix(3)`).
    func fetchHomeRecentNotes(limit: Int = 3) async throws -> [HomeRecentNote] {
        async let unfinished = fetchUnfinishedNotes()
        async let ambient = fetchInProgressAmbientSessions()
        let notes = try await unfinished
        let sessions = (try? await ambient) ?? InProgressAmbientSessionsResponse(sessions: nil, patients: nil)
        return buildRecentNotes(
            unfinished: notes,
            ambient: sessions,
            limit: limit
        )
    }

    /// Full unfinished list (iOS `UnfinishedNoteClient.initialLoadUnfinishedNotes`).
    func fetchUnfinishedNotesList() async throws -> [HomeRecentNote] {
        let items = try await fetchUnfinishedNotes()
        return items
            .filter { !$0.isAmbientInProgress }
            .sorted { $0.unfinishedSortDate > $1.unfinishedSortDate }
            .map { mapUnfinishedNoteToRow($0) }
    }

    func fetchUnfinishedNotes() async throws -> [NoteListItem] {
        let descriptor = APIRequestDescriptor(
            host: .v2,
            path: "/compositions/unfinished-count",
            method: "GET",
            query: [
                "includeMetadata": "true",
                "includeSections": "false"
            ]
        )
        let response = try await api.send(descriptor, as: UnfinishedNotesResponse.self)
        return response.results
    }

    private func fetchInProgressAmbientSessions() async throws -> InProgressAmbientSessionsResponse {
        guard let userId = sessionStore.userId, let orgId = sessionStore.organizationId else {
            throw APIError.server(-1, "Missing session")
        }
        let descriptor = APIRequestDescriptor(
            host: .gateway,
            path: "/v1/ambient/sessions",
            method: "GET",
            query: [
                "user_id": userId,
                "organisation_id": orgId,
                "ambient_statuses": "IN_PROGRESS",
                "with_patients": "true"
            ]
        )
        return try await api.send(descriptor, as: InProgressAmbientSessionsResponse.self)
    }

    private struct SortableRow {
        var sortDate: Date
        var note: HomeRecentNote
    }

    private func buildRecentNotes(
        unfinished: [NoteListItem],
        ambient: InProgressAmbientSessionsResponse,
        limit: Int
    ) -> [HomeRecentNote] {
        let todaysUnfinished = unfinished.filter { note in
            NoteDateClassification.isToday(iso: note.createdAt)
                || NoteDateClassification.isToday(iso: note.updatedAt)
        }

        var patientsById: [String: AmbientSessionPatient] = [:]
        for patient in ambient.patients ?? [] {
            guard let id = patient.id, !id.isEmpty else { continue }
            patientsById[id] = patient
        }

        var rows: [SortableRow] = []

        for note in todaysUnfinished {
            rows.append(
                SortableRow(
                    sortDate: NoteDateClassification.mostRecentDate(createdAt: note.createdAt, updatedAt: note.updatedAt),
                    note: mapUnfinishedNoteToRow(note, timeLabel: DateRangeFormatter.appointmentTimeLabel(iso: note.updatedAt ?? note.createdAt))
                )
            )
        }

        for session in ambient.sessions ?? [] {
            guard NoteDateClassification.isToday(iso: session.startTime),
                  session.isAutoSubmit != true,
                  session.isNoteCreated != true
            else { continue }

            let patient = patientsById[session.patientId ?? ""]
            let patientName = patient?.displayName
                ?? session.patientLabel
                ?? "Patient"
            let noteId = session.noteId?.isEmpty == false ? session.noteId : nil
            let rowId = noteId ?? session.ambientSessionId ?? UUID().uuidString
            let sortDate = NoteDateClassification.parseCreatedAt(session.startTime) ?? .distantPast

            rows.append(
                SortableRow(
                    sortDate: sortDate,
                    note: HomeRecentNote(
                        id: rowId,
                        noteId: noteId,
                        patientId: session.patientId,
                        patientName: patientName,
                        headline: patientName,
                        subtitle: "Ambient visit",
                        timeLabel: DateRangeFormatter.appointmentTimeLabel(iso: session.startTime),
                        isIncomplete: true
                    )
                )
            )
        }

        return rows
            .sorted { $0.sortDate > $1.sortDate }
            .prefix(limit)
            .map(\.note)
    }

    private func mapUnfinishedNoteToRow(_ note: NoteListItem, timeLabel: String? = nil) -> HomeRecentNote {
        let patientName = note.metadata?.patient?.displayName
            ?? note.metadata?.patientLabel
        let noteTypeName = note.metadata?.name ?? "Note"
        let label = timeLabel ?? note.dateOfServiceLabel
        return HomeRecentNote(
            id: note.stableId,
            noteId: note.stableId,
            patientId: note.metadata?.patient?.id,
            patientName: patientName,
            headline: patientName?.isEmpty == false ? patientName! : (note.metadata?.patientLabel ?? "Unknown patient"),
            subtitle: noteTypeName,
            timeLabel: label,
            isIncomplete: note.isUnfinished
        )
    }
}
