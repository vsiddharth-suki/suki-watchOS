import Foundation

enum AmbientStep: Int, CaseIterable {
    case recording
    case patient
    case noteType
    case finishing
    case done
}

enum AmbientFinishAction {
    case reviewNote
    case sendToEHR
}

@Observable
@MainActor
final class AmbientFlowViewModel {
    let launch: AmbientLaunchContext

    var step: AmbientStep = .recording
    var isRecording = false
    var isPaused = false
    var selectedPatient: PatientSearchResult?
    var noteTypes: [NoteTypeItem] = []
    var selectedNoteType: NoteTypeItem?
    var isLoading = false
    var errorMessage: String?
    var completionMessage: String?

    private let ambientService = AmbientService()
    private let noteService = NoteService()
    private let patientService = PatientService()
    var searchQuery = ""
    var searchResults: [PatientSearchResult] = []

    init(launch: AmbientLaunchContext) {
        self.launch = launch
        if let patientId = launch.patientId {
            selectedPatient = PatientSearchResult(id: patientId, mrn: nil, person: PersonName(firstName: launch.patientName, lastName: nil, preferredName: nil))
        }
    }

    func start() async {
        errorMessage = nil
        do {
            try ambientService.beginSession()
            isRecording = true
            isPaused = false
            if launch.startWithoutPatient {
                step = .recording
            } else if launch.noteId != nil {
                step = .recording
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func togglePause() {
        if isPaused {
            ambientService.resumeRecording()
            isPaused = false
        } else {
            ambientService.pauseRecording()
            isPaused = true
        }
    }

    func goToPatientStep() {
        if launch.noteId != nil {
            step = .noteType
            Task { await loadNoteTypes() }
            return
        }
        if launch.patientId != nil {
            step = .noteType
            Task { await loadNoteTypes() }
        } else {
            step = .patient
        }
    }

    func searchPatients() async {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            searchResults = try await patientService.searchPatients(name: trimmed)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectPatient(_ patient: PatientSearchResult) {
        selectedPatient = patient
        step = .noteType
        Task { await loadNoteTypes() }
    }

    func loadNoteTypes() async {
        isLoading = true
        defer { isLoading = false }
        do {
            noteTypes = try await noteService.fetchNoteTypes()
            if selectedNoteType == nil {
                selectedNoteType = noteTypes.first
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func finishAmbient(action: AmbientFinishAction) {
        isLoading = true
        errorMessage = nil
        completionMessage = nil
        ambientService.stopRecording()
        isRecording = false
        isPaused = false
        step = .finishing

        let autoSubmit = action == .sendToEHR
        let patientId = selectedPatient?.id ?? launch.patientId
        let noteTypeId = launch.noteId == nil ? selectedNoteType?.id : nil
        let noteId = launch.noteId
        let appointmentId = launch.appointmentId
        let service = ambientService

        AmbientSessionCompletion.shared.start(service: service) {
            try await service.submitMetadata(
                noteTypeId: noteTypeId,
                noteId: noteId,
                patientId: patientId,
                appointmentId: appointmentId,
                autoSubmitToEMR: autoSubmit
            )
            try await service.uploadRecordingIfNeeded()
        } onComplete: { [weak self] result in
            guard let self else { return }
            isLoading = false
            switch result {
            case .success:
                switch action {
                case .reviewNote:
                    completionMessage = "Ambient session saved. Review the note from the patient profile when ready."
                case .sendToEHR:
                    completionMessage = "Ambient session saved. Note will auto-submit to the EHR when ready."
                }
                step = .done
            case .failure(let error):
                errorMessage = error.localizedDescription
                step = .noteType
            }
        }
    }

    /// Called when the ambient screen is popped (back). Upload/metadata finish continues in background.
    func handleNavigationAway() {
        if AmbientSessionCompletion.shared.isRunning { return }
        switch step {
        case .finishing, .done:
            return
        default:
            break
        }
        abortSessionIfActive()
    }

    private func abortSessionIfActive() {
        ambientService.cancelSession()
        isRecording = false
        isPaused = false
    }

}
