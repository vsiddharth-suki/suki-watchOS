import SwiftUI

struct AmbientFlowView: View {
    @Environment(\.dismiss) private var dismiss
    let launch: AmbientLaunchContext

    @State private var viewModel: AmbientFlowViewModel

    init(launch: AmbientLaunchContext) {
        self.launch = launch
        _viewModel = State(initialValue: AmbientFlowViewModel(launch: launch))
    }

    var body: some View {
        List {
            switch viewModel.step {
            case .recording:
                recordingStep
            case .patient:
                patientStep
            case .noteType:
                noteTypeStep
            case .finishing:
                finishingStep
            case .done:
                doneStep
            }

            if let error = viewModel.errorMessage {
                Text(error).font(.caption2).foregroundStyle(.red)
            }
        }
        .navigationTitle("Ambient")
        .task { await viewModel.start() }
    }

    @ViewBuilder
    private var recordingStep: some View {
        Section {
            if viewModel.isRecording {
                HStack(alignment: .center, spacing: 8) {
                    if viewModel.isPaused {
                        Text("Paused")
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 4)
                        Image(systemName: "pause.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.orange)
                    } else {
                        Text("Recording…")
                        Spacer(minLength: 4)
                        RecordingMicView(compact: true)
                    }
                }

                Button(viewModel.isPaused ? "Resume" : "Pause") {
                    viewModel.togglePause()
                }
            }
            Button("Next") {
                viewModel.goToPatientStep()
            }
        }
    }

    @ViewBuilder
    private var patientStep: some View {
        Section("Patient") {
            TextField("Search", text: $viewModel.searchQuery)
                .onSubmit { Task { await viewModel.searchPatients() } }
            if viewModel.isLoading { ProgressView() }
            ForEach(viewModel.searchResults, id: \.stableId) { patient in
                Button(patient.displayName) {
                    viewModel.selectPatient(patient)
                }
            }
        }
    }

    @ViewBuilder
    private var noteTypeStep: some View {
        Section {
            Button("Review note") {
                Task { await viewModel.finishAmbient(action: .reviewNote) }
            }
            .disabled(viewModel.selectedNoteType == nil && launch.noteId == nil)

            Button("Send to EHR") {
                Task { await viewModel.finishAmbient(action: .sendToEHR) }
            }
            .disabled(viewModel.selectedNoteType == nil && launch.noteId == nil)
        }

        Section("Note type") {
            if viewModel.isLoading { ProgressView() }
            ForEach(viewModel.noteTypes) { type in
                Button {
                    viewModel.selectedNoteType = type
                } label: {
                    HStack {
                        Text(type.name)
                            .font(.caption)
                        if viewModel.selectedNoteType?.id == type.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var finishingStep: some View {
        Section {
            ProgressView()
            Text("Uploading…")
        }
    }

    @ViewBuilder
    private var doneStep: some View {
        Section {
            if let message = viewModel.completionMessage {
                Text(message)
                    .font(.caption)
            }
            Button("Done") {
                dismiss()
            }
        }
    }
}
