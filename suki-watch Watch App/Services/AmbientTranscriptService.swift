import Foundation

/// iOS `ViewTranscriptsAPIManager` + `getAmbientTranscripts` gateway APIs.
final class AmbientTranscriptService {
    private let api: APIClient
    private let sessionStore: SessionStore

    init(api: APIClient = APIClient(), sessionStore: SessionStore = .shared) {
        self.api = api
        self.sessionStore = sessionStore
    }

    func fetchSessions(forNoteIds noteIds: [String]) async throws -> [AmbientNoteSession] {
        guard let userId = sessionStore.userId, let orgId = sessionStore.organizationId else {
            throw APIError.server(-1, "Missing session")
        }
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "user_id", value: userId),
            URLQueryItem(name: "organisation_id", value: orgId),
            URLQueryItem(name: "patient_id", value: ""),
            URLQueryItem(name: "latest", value: "false")
        ]
        for id in noteIds where !id.isEmpty {
            queryItems.append(URLQueryItem(name: "note_ids", value: id))
        }
        let descriptor = APIRequestDescriptor(
            host: .gateway,
            path: "/v1/ambient/sessions",
            method: "GET",
            queryItems: queryItems
        )
        let response = try await api.send(descriptor, as: AmbientNoteSessionsResponse.self)
        return response.sessions ?? []
    }

    func fetchTranscript(ambientSessionId: String) async throws -> AmbientSessionTranscriptResponse {
        let descriptor = APIRequestDescriptor(
            host: .gateway,
            path: "/v1/ambient/sessions/\(ambientSessionId)/transcripts",
            method: "GET"
        )
        return try await api.send(descriptor, as: AmbientSessionTranscriptResponse.self)
    }
}
