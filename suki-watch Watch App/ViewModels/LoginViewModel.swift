import Foundation

@Observable
@MainActor
final class LoginViewModel {
    var email = ""
    var password = ""
    var isLoading = false
    var errorMessage: String?

    private let authService = OktaAuthService()
    private let sessionStore = SessionStore.shared
    private let userProfileService = UserProfileService()
    func signIn() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let (tokens, rawInfo) = try await authService.signIn(username: email, password: password)
            let merged = authService.mergeUserInfo(rawInfo, idToken: tokens.idToken)
            guard merged.userID != nil, merged.organizationID != nil else {
                throw OktaAuthError.missingUserInfo
            }
            sessionStore.apply(
                tokens: tokens,
                userInfo: merged,
                email: email.isEmpty ? (merged.email ?? "") : email
            )
            try? await userProfileService.fetchAndApplyCurrentUser(onLogin: true)
            await sessionStore.refreshEMRMembership()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
