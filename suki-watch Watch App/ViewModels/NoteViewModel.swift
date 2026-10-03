import Foundation
import SukiGRPC

struct EditableSection: Identifiable, Hashable {
    let id: String
    var name: String
    var text: String
    /// Text loaded from the server. Unchanged sections are not written back on submit.
    var loadedText: String
}

@Observable
@MainActor
final class NoteViewModel {
    let noteId: String
    let patientId: String?
    let patientName: String?

    var noteTitle = "Note"
    var showAmbientTranscriptButton = false
    var ambientTranscriptNoteIds: [String] = []
    var sections: [EditableSection] = []
    var isLoading = false
    var isSubmitting = false
    var isSavingSections = false
    var sectionSaveErrorMessage: String?
    var isDeleting = false
    var isSubmittedNote = false
    var errorMessage: String?
    var showSubmittedAlert = false
    var submitErrorMessage: String?
    var deleteErrorMessage: String?

    private let noteService = NoteService()
    private let transcriptService = AmbientTranscriptService()
    private let submitService = NoteSubmitService()
    private let session = SessionStore.shared
    private var didLoadContent = false

    private var compositionId: String?
    private var noteTypeId: String?
    private var resolvedPatientId: String?
    private var appointmentId: String?

    init(noteId: String, patientId: String?, patientName: String?) {
        self.noteId = noteId
        self.patientId = patientId
        self.patientName = patientName
    }

    func load() async {
        guard !didLoadContent else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let detail = try await noteService.fetchNoteDetail(noteId: noteId)
            compositionId = detail.compositionId ?? detail.id ?? detail.noteId ?? noteId
            noteTypeId = detail.metadata?.noteTypeId
            resolvedPatientId = detail.metadata?.patient?.id ?? patientId
            appointmentId = detail.metadata?.appointment?.id
            noteTitle = detail.metadata?.name ?? "Note"
            let raw = (detail.sectionsS2?.isEmpty == false ? detail.sectionsS2 : detail.sections) ?? []
            sections = raw.compactMap { section in
                guard let sectionId = section.id, !sectionId.isEmpty else { return nil }
                return EditableSection(
                    id: sectionId,
                    name: section.name ?? "Section",
                    text: section.bodyText,
                    loadedText: section.bodyText
                )
            }
            if sections.isEmpty, let first = raw.first {
                let body = first.bodyText
                sections = [
                    EditableSection(
                        id: first.id ?? first.name ?? "section-0",
                        name: first.name ?? "Section",
                        text: body,
                        loadedText: body
                    )
                ]
            }
            isSubmittedNote = NoteListItem.isSubmittedStatus(detail.metadata?.status)
                || (detail.readOnly == true)
            didLoadContent = true
            await refreshAmbientTranscriptAvailability()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshAmbientTranscriptAvailability() async {
        var noteIds = [noteId]
        if let compositionId, !compositionId.isEmpty, compositionId != noteId {
            noteIds.append(compositionId)
        }
        do {
            let sessions = try await transcriptService.fetchSessions(forNoteIds: noteIds)
            ambientTranscriptNoteIds = noteIds
            showAmbientTranscriptButton = !sessions.isEmpty
        } catch {
            ambientTranscriptNoteIds = []
            showAmbientTranscriptButton = false
        }
    }

    /// iOS `shipTypedUpdates`: `UPDATE_SECTION` with `content_s2` for sections whose text changed.
    func persistSectionEdits() async {
        guard !isSavingSections, !isSubmitting, !isSubmittedNote else { return }
        guard sections.contains(where: { $0.text != $0.loadedText }) else { return }
        guard let payload = makeSubmitPayload() else { return }

        isSavingSections = true
        sectionSaveErrorMessage = nil
        defer { isSavingSections = false }
        do {
            try await submitService.persistSectionEdits(payload: payload, session: session)
            for index in sections.indices {
                sections[index].loadedText = sections[index].text
            }
        } catch {
            sectionSaveErrorMessage = error.localizedDescription
        }
    }

    func sendNote() {
        guard !isSubmitting, !isSubmittedNote else { return }
        submitErrorMessage = nil

        guard let compositionId, !compositionId.isEmpty else {
            submitErrorMessage = "Missing composition id."
            return
        }
        guard let noteTypeId, !noteTypeId.isEmpty else {
            submitErrorMessage = "Missing note type."
            return
        }
        let patientIdForSubmit = resolvedPatientId ?? patientId ?? ""
        guard !patientIdForSubmit.isEmpty else {
            submitErrorMessage = "Missing patient for this note."
            return
        }

        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                guard let payload = makeSubmitPayload() else { return }
                try await submitService.submit(payload: payload, session: session)
                isSubmittedNote = true
                showSubmittedAlert = true
            } catch {
                submitErrorMessage = error.localizedDescription
            }
        }
    }

    private func makeSubmitPayload() -> NoteSubmitPayload? {
        guard let compositionId, !compositionId.isEmpty else {
            submitErrorMessage = "Missing composition id."
            return nil
        }
        guard let noteTypeId, !noteTypeId.isEmpty else {
            submitErrorMessage = "Missing note type."
            return nil
        }
        let patientIdForSubmit = resolvedPatientId ?? patientId ?? ""
        guard !patientIdForSubmit.isEmpty else {
            submitErrorMessage = "Missing patient for this note."
            return nil
        }
        return NoteSubmitPayload(
            compositionId: compositionId,
            noteTypeId: noteTypeId,
            patientId: patientIdForSubmit,
            appointmentId: appointmentId ?? "",
            sections: sections.map {
                NoteSubmitSection(
                    id: $0.id,
                    name: $0.name,
                    plainText: $0.text,
                    loadedPlainText: $0.loadedText
                )
            }
        )
    }

    /// Deletes the note via REST; returns `true` when the caller should dismiss the screen.
    func deleteNote() async -> Bool {
        guard !isDeleting, !isSubmittedNote else { return false }
        deleteErrorMessage = nil
        guard let compositionId, !compositionId.isEmpty else {
            deleteErrorMessage = "Missing composition id."
            return false
        }
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await noteService.deleteComposition(compositionId: compositionId)
            return true
        } catch {
            deleteErrorMessage = error.localizedDescription
            return false
        }
    }

    var ambientContext: AmbientLaunchContext {
        AmbientLaunchContext(
            patientId: patientId,
            patientName: patientName,
            appointmentId: nil,
            noteId: noteId,
            startWithoutPatient: false
        )
    }
}
