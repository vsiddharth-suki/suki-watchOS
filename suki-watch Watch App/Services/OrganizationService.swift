import Foundation

/// iOS `NetworkManager.checkEMRStatus` — org has linked EMR when `emr.id` is present.
final class OrganizationService {
    private let api: APIClient

    init(api: APIClient = APIClient()) {
        self.api = api
    }

    func fetchBelongsToEMR(organizationId: String) async throws -> Bool {
        let descriptor = APIRequestDescriptor(
            host: .v2,
            path: "/organizations/\(organizationId)",
            method: "GET",
            query: ["withEmrInfo": "true"]
        )
        let response = try await api.send(descriptor, as: OrganisationResponse.self)
        guard let organization = response.organizations.first else { return false }
        let emrId = organization.emr?.id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !emrId.isEmpty
    }
}
