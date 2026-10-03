import SwiftUI

struct NoteView: View {
    @Binding var path: [AppRoute]
    @State private var viewModel: NoteViewModel
    @State private var showDeleteConfirmation = false

    init(path: Binding<[AppRoute]>, noteId: String, patientId: String?, patientName: String?) {
        _path = path
        _viewModel = State(initialValue: NoteViewModel(noteId: noteId, patientId: patientId, patientName: patientName))
    }

    var body: some View {
        @Bindable var model = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if model.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if let error = model.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                } else {
                    HStack(alignment: .center, spacing: 6) {
                        Text(model.noteTitle)
                            .font(.headline)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if model.showAmbientTranscriptButton {
                            Button {
                                path.append(.ambientTranscripts(noteIds: viewModel.ambientTranscriptNoteIds, patientName: viewModel.patientName))
                            } label: {
                                Image(systemName: "note.text")
                                    .font(.body)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Ambient Transcript")
                        }
                    }

                    Button("Start Ambient") {
                        path.append(.ambient(model.ambientContext))
                    }

                    ForEach($model.sections) { $section in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(section.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            NoteSectionEditor(
                                text: $section.text,
                                sectionName: section.name,
                                isEditable: !model.isSubmittedNote
                            ) {
                                Task { await viewModel.persistSectionEdits() }
                            }
                        }
                    }
                }

                if let saveError = model.sectionSaveErrorMessage {
                    Text(saveError)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
                if let submitError = model.submitErrorMessage {
                    Text(submitError)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
                if let deleteError = model.deleteErrorMessage {
                    Text(deleteError)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }

                Button(model.isSubmitting ? "Sending…" : "Send") {
                    model.sendNote()
                }
                .disabled(model.isSubmitting || model.isSavingSections || model.isLoading || model.isSubmittedNote)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)

                Button(model.isDeleting ? "Deleting…" : "Delete", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .disabled(model.isDeleting || model.isLoading || model.isSubmittedNote)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
        }
        .navigationTitle(model.patientName ?? "Patient")
        .overlay {
            if model.isSubmitting {
                InProgressOverlay()
            }
        }
        .task(id: viewModel.noteId) { await viewModel.load() }
        .onDisappear {
            guard !viewModel.isSubmittedNote else { return }
            Task { await viewModel.persistSectionEdits() }
        }
        .alert("Note submitted", isPresented: $model.showSubmittedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your note was submitted successfully.")
        }
        .alert("Delete Note?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.deleteNote() {
                        if !path.isEmpty { path.removeLast() }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
