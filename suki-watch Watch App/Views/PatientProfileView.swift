import SwiftUI

struct PatientProfileView: View {
    @Binding var path: [AppRoute]
    let patientId: String
    let patientName: String
    let appointmentId: String?

    @State private var viewModel: PatientProfileViewModel

    init(path: Binding<[AppRoute]>, patientId: String, patientName: String, appointmentId: String?) {
        _path = path
        self.patientId = patientId
        self.patientName = patientName
        self.appointmentId = appointmentId
        _viewModel = State(initialValue: PatientProfileViewModel(patientId: patientId, patientName: patientName, appointmentId: appointmentId))
    }

    var body: some View {
        @Bindable var model = viewModel
        List {
            Section {
                Button("Start Ambient") {
                    path.append(.ambient(AmbientLaunchContext(
                        patientId: patientId,
                        patientName: patientName,
                        appointmentId: appointmentId,
                        noteId: nil,
                        startWithoutPatient: false
                    )))
                }
                Button(model.isCreatingNote ? "Creating…" : "New Note") {
                    Task { await model.prepareCreateNote() }
                }
                .disabled(model.isCreatingNote)
            }

            if let error = model.errorMessage {
                Section {
                    Text(error).font(.caption2).foregroundStyle(.red)
                }
            }

            Section("Current Notes") {
                if model.currentNotes.isEmpty {
                    Text("None").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(model.currentNotes, id: \.stableId) { note in
                        noteRow(note)
                    }
                }
            }

            Section("Prior Notes") {
                if model.priorNotes.isEmpty {
                    Text("None").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(model.priorNotes, id: \.stableId) { note in
                        noteRow(note)
                    }
                }
            }
        }
        .navigationTitle(patientName)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .overlay {
            if viewModel.isLoading && !viewModel.showCreateNoteSheet {
                InProgressOverlay()
            }
        }
        .sheet(isPresented: $model.showCreateNoteSheet) {
            createNoteSheet
        }
    }

    @ViewBuilder
    private var createNoteSheet: some View {
        @Bindable var model = viewModel
        List {
            Section("Note type") {
                ForEach(model.noteTypes) { type in
                    Button {
                        Task {
                            if let noteId = await model.createNote(noteType: type) {
                                path.append(.note(noteId: noteId, patientId: patientId, patientName: patientName))
                            }
                        }
                    } label: {
                        Text(type.name).font(.caption)
                    }
                    .disabled(model.isCreatingNote)
                }
            }
        }
        .navigationTitle("New Note")
        .overlay {
            if model.isCreatingNote {
                InProgressOverlay()
            }
        }
    }

    @ViewBuilder
    private func noteRow(_ note: NoteListItem) -> some View {
        Button {
            path.append(.note(noteId: note.stableId, patientId: patientId, patientName: patientName))
        } label: {
            PatientProfileNoteRowView(note: note)
        }
    }
}

private struct PatientProfileNoteRowView: View {
    let note: NoteListItem
    private let statusIconColumnWidth: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 6) {
                NoteStatusIcon(isSubmitted: note.isSubmitted)
                    .frame(width: statusIconColumnWidth, alignment: .center)
                Text(note.title)
                    .font(.caption)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(note.patientProfileDateLine)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, statusIconColumnWidth + 6)
        }
    }
}

private struct NoteStatusIcon: View {
    let isSubmitted: Bool

    var body: some View {
        Group {
            if isSubmitted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.orange)
            }
        }
        .frame(height: 14, alignment: .center)
    }
}
