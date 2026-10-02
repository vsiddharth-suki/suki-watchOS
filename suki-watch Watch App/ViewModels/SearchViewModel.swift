import Foundation

@Observable
@MainActor
final class SearchViewModel {
    var query = ""
    var results: [PatientSearchResult] = []
    var isLoading = false
    var errorMessage: String?

    private let patientService = PatientService()

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            results = try await patientService.searchPatients(name: trimmed)
        } catch {
            errorMessage = error.localizedDescription
            results = []
        }
    }
}
