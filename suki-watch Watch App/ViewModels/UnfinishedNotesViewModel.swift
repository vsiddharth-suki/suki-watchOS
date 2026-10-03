import Foundation

@Observable
@MainActor
final class UnfinishedNotesViewModel {
    var notes: [HomeRecentNote] = []
    var isLoading = false
    var errorMessage: String?

    private let recentNotesService = RecentNotesService()

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            notes = try await recentNotesService.fetchUnfinishedNotesList()
        } catch {
            notes = []
            errorMessage = error.localizedDescription
        }
    }
}
