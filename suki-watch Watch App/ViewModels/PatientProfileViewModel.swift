import Foundation

@Observable
@MainActor
final class PatientProfileViewModel {
    let patientId: String
    let patientName: String
    let appointmentId: String?

    var currentNotes: [NoteListItem] = []
    var priorNotes: [NoteListItem] = []
    var noteTypes: [NoteTypeItem] = []
    var isLoading = false
    var isCreatingNote = false
    var errorMessage: String?
    var showCreateNoteSheet = false

    private let noteService = NoteService()

    init(patientId: String, patientName: String, appointmentId: String?) {
        self.patientId = patientId
        self.patientName = patientName
        self.appointmentId = appointmentId
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let visible = try await noteService.notesForPatientProfile(patientId: patientId)
            let split = noteService.splitNotes(visible)
            currentNotes = split.current
            priorNotes = split.prior
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func prepareCreateNote() async {
        errorMessage = nil
        if noteTypes.isEmpty {
            isLoading = true
            defer { isLoading = false }
            do {
                noteTypes = try await noteService.fetchNoteTypes()
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }
        showCreateNoteSheet = true
    }

    func createNote(noteType: NoteTypeItem) async -> String? {
        isCreatingNote = true
        errorMessage = nil
        defer {
            isCreatingNote = false
            showCreateNoteSheet = false
        }
        do {
            let noteId = try await noteService.createNote(
                noteTypeId: noteType.id,
                patientId: patientId,
                appointmentId: appointmentId
            )
            await load()
            return noteId
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
