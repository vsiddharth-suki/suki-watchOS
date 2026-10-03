import Foundation

final class NoteService {
    private let api: APIClient

    init(api: APIClient = APIClient()) {
        self.api = api
    }

    func fetchNotes(patientId: String) async throws -> [NoteListItem] {
        let descriptor = APIRequestDescriptor(
            host: .v2,
            path: "/notes",
            method: "GET",
            query: ["patientId": patientId]
        )
        let response = try await api.send(descriptor, as: NotesListResponse.self)
        return response.results
    }

    func notesForPatientProfile(patientId: String, session: SessionStore = .shared) async throws -> [NoteListItem] {
        let all = try await fetchNotes(patientId: patientId)
        return all.filter { $0.shouldShowOnPatientProfile(currentUserId: session.userId) }
    }

    /// iOS `NoteNetworkManager.deleteComposition` — `DELETE /compositions/{id}`.
    func deleteComposition(compositionId: String) async throws {
        let descriptor = APIRequestDescriptor(
            host: .v2,
            path: "/compositions/\(compositionId)",
            method: "DELETE"
        )
        let response = try await api.send(descriptor, as: DeleteCompositionResponse.self)
        guard response.success == true else {
            throw APIError.server(-1, "Could not delete note.")
        }
    }

    func fetchNoteDetail(noteId: String) async throws -> CompositionOrNoteData {
        let descriptor = APIRequestDescriptor(
            host: .v2,
            path: "/notes/compositionOrNote/\(noteId)",
            method: "GET"
        )
        let response = try await api.send(descriptor, as: CompositionOrNoteResponse.self)
        guard let data = response.data else {
            throw APIError.server(-1, "Empty note payload")
        }
        return data
    }

    func fetchNoteTypes() async throws -> [NoteTypeItem] {
        let descriptor = APIRequestDescriptor(
            host: .v2,
            path: "/note-types",
            method: "GET"
        )
        let response = try await api.send(descriptor, as: NoteTypesResponse.self)
        return response.noteTypes ?? []
    }

    func splitNotes(_ notes: [NoteListItem]) -> (current: [NoteListItem], prior: [NoteListItem]) {
        let sorted = notes.sorted { lhs, rhs in
            let left = NoteDateClassification.parseCreatedAt(lhs.compositionCreatedDateString) ?? .distantPast
            let right = NoteDateClassification.parseCreatedAt(rhs.compositionCreatedDateString) ?? .distantPast
            return left > right
        }
        var current: [NoteListItem] = []
        var prior: [NoteListItem] = []
        for note in sorted {
            if NoteDateClassification.isCurrentSectionNote(createdAt: note.effectiveDateString) {
                current.append(note)
            } else {
                prior.append(note)
            }
        }
        return (current, prior)
    }

    func createNote(
        noteTypeId: String,
        patientId: String,
        appointmentId: String?,
        session: SessionStore = .shared
    ) async throws -> String {
        let submitService = NoteSubmitService()
        return try await submitService.createNote(
            noteTypeId: noteTypeId,
            patientId: patientId,
            appointmentId: appointmentId,
            session: session
        )
    }
}
