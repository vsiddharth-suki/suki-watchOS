import SwiftUI

struct UnfinishedNotesView: View {
    @Binding var path: [AppRoute]
    @State private var viewModel = UnfinishedNotesViewModel()

    var body: some View {
        List {
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.errorMessage {
                Text(error).font(.caption2).foregroundStyle(.red)
            } else if viewModel.notes.isEmpty {
                Text("No unfinished notes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.notes) { note in
                    Button {
                        openNote(note)
                    } label: {
                        RecentNoteRowView(note: note)
                    }
                }
            }
        }
        .navigationTitle("Unfinished Notes")
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private func openNote(_ note: HomeRecentNote) {
        guard let noteId = note.noteId, !noteId.isEmpty else { return }
        path.append(.note(
            noteId: noteId,
            patientId: note.patientId,
            patientName: note.patientName
        ))
    }
}
