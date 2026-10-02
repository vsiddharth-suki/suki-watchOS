import Foundation

/// Loads the signed-in user's profile from `/auth/me` (iOS `UserClient.getUser`).
final class UserProfileService {
    private let api: APIClient
    private let sessionStore: SessionStore

    init(api: APIClient = APIClient(), sessionStore: SessionStore = .shared) {
        self.api = api
        self.sessionStore = sessionStore
    }

    func fetchAndApplyCurrentUser(onLogin: Bool) async throws {
        guard let userId = sessionStore.userId, !userId.isEmpty else { return }
        let body = try JSONEncoder().encode(AuthMeRequestBody(userId: userId, onLogin: onLogin))
        let descriptor = APIRequestDescriptor(
            host: .v2,
            path: "/auth/me",
            method: "POST",
            body: body
        )
        let response = try await api.send(descriptor, as: CurrentUserResponse.self)
        sessionStore.applyWelcomeProfile(
            firstName: response.user.person?.firstName,
            prefix: response.user.person?.prefix
        )
    }
}
