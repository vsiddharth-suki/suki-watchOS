import Foundation

final class PatientService {
    private let api: APIClient

    init(api: APIClient = APIClient()) {
        self.api = api
    }

    func searchPatients(name: String) async throws -> [PatientSearchResult] {
        let descriptor = APIRequestDescriptor(
            host: .v2,
            path: "/patients/search",
            method: "GET",
            query: [
                "name": name,
                "limit": "25"
            ]
        )
        let response = try await api.send(descriptor, as: APIListResponse<PatientSearchResult>.self)
        return response.results ?? []
    }
}
