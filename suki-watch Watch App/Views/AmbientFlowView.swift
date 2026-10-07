import SwiftUI

struct AmbientFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Bindable private var session = SessionStore.shared
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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                viewModel.pauseForSystemInterruption()
            }
        }
        .onDisappear {
            viewModel.handleNavigationAway()
        }
    }

    @ViewBuilder
    private var recordingStep: some View {
        Section {
            if viewModel.isRecording {
                HStack(alignment: .center, spacing: 6) {
                    Group {
                        if viewModel.isPaused {
                            Text("Paused")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Recording")
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .allowsTightening(true)
                    .layoutPriority(1)

                    if viewModel.isPaused {
                        RecordingPausedView(compact: true)
                    } else {
                        RecordingMicView(compact: true)
                    }

                    Spacer(minLength: 0)

                    Text(viewModel.recordingDurationLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(viewModel.isPaused ? .secondary : .primary)
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(2)
                }

                Button(viewModel.isPaused ? "Resume" : "Pause") {
                    viewModel.togglePause()
                }
            }
            Button("Submit") {
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
            Button("Review Note") {
                viewModel.finishAmbient(action: .reviewNote)
            }
            .disabled(viewModel.selectedNoteType == nil && launch.noteId == nil)

            if session.belongsToEMR {
                Button("Send to EHR") {
                    viewModel.finishAmbient(action: .sendToEHR)
                }
                .disabled(viewModel.selectedNoteType == nil && launch.noteId == nil)
            }
        }

        if !viewModel.isAmbientForExistingNote {
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
