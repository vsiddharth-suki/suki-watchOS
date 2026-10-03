import Foundation

@Observable
final class SessionStore {
    static let shared = SessionStore()

    private enum Keys {
        static let accessToken = "suki.watch.accessToken"
        static let idToken = "suki.watch.idToken"
        static let userId = "suki.watch.userId"
        static let organizationId = "suki.watch.organizationId"
        static let email = "suki.watch.email"
        static let sessionId = "suki.watch.sessionId"
        static let userFirstName = "suki.watch.userFirstName"
        static let userLastName = "suki.watch.userLastName"
        static let userPrefix = "suki.watch.userPrefix"
    }

    /// Drives login vs home UI; updated explicitly so SwiftUI observes auth changes.
    private(set) var isAuthenticated = false

    var accessToken: String? {
        get { UserDefaults.standard.string(forKey: Keys.accessToken) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.accessToken) }
    }

    var idToken: String? {
        get { UserDefaults.standard.string(forKey: Keys.idToken) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.idToken) }
    }

    /// Okta ID token for gRPC `jwt_token` (falls back to access token for older sessions).
    var grpcJWTToken: String? {
        if let idToken, !idToken.isEmpty { return idToken }
        return accessToken
    }

    var userId: String? {
        get { UserDefaults.standard.string(forKey: Keys.userId) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.userId) }
    }

    var organizationId: String? {
        get { UserDefaults.standard.string(forKey: Keys.organizationId) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.organizationId) }
    }

    var email: String? {
        get { UserDefaults.standard.string(forKey: Keys.email) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.email) }
    }

    var sessionId: String {
        if let existing = UserDefaults.standard.string(forKey: Keys.sessionId), !existing.isEmpty {
            return existing
        }
        let newValue = UUID().uuidString
        UserDefaults.standard.set(newValue, forKey: Keys.sessionId)
        return newValue
    }

    var isLoggedIn: Bool { isAuthenticated }

    var userFirstName: String? {
        get { UserDefaults.standard.string(forKey: Keys.userFirstName) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.userFirstName) }
    }

    var userLastName: String? {
        get { UserDefaults.standard.string(forKey: Keys.userLastName) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.userLastName) }
    }

    var userPrefix: String? {
        get { UserDefaults.standard.string(forKey: Keys.userPrefix) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.userPrefix) }
    }

    /// Refetch `/auth/me` when first name is missing or last name was never stored (older app versions).
    var shouldRefreshWelcomeProfile: Bool {
        let first = userFirstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if first.isEmpty { return true }
        return UserDefaults.standard.object(forKey: Keys.userLastName) == nil
    }

    var welcomeDoctorLabel: String {
        let first = userFirstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let last = userLastName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
        guard !name.isEmpty else { return "Welcome" }
        return "Welcome \(name)"
    }

    init() {
        restoreSessionIfPossible()
    }

    func apply(tokens: OktaTokenResponse, userInfo: OktaUserInfo, email: String) {
        accessToken = tokens.accessToken
        idToken = tokens.idToken
        userId = userInfo.userID
        organizationId = userInfo.organizationID
        self.email = email
        isAuthenticated = userId != nil && accessToken != nil
    }

    func applyWelcomeProfile(firstName: String?, lastName: String?, prefix: String?) {
        let trimmedFirst = firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedLast = lastName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedPrefix = prefix?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        userFirstName = trimmedFirst.isEmpty ? nil : trimmedFirst
        userLastName = trimmedLast
        userPrefix = trimmedPrefix.isEmpty ? nil : trimmedPrefix
    }

    func signOut() {
        accessToken = nil
        idToken = nil
        userId = nil
        organizationId = nil
        email = nil
        userFirstName = nil
        userLastName = nil
        userPrefix = nil
        UserDefaults.standard.removeObject(forKey: Keys.sessionId)
        isAuthenticated = false
    }

    private func restoreSessionIfPossible() {
        let hasToken = accessToken?.isEmpty == false
        let hasUser = userId?.isEmpty == false
        isAuthenticated = hasToken && hasUser
        if !isAuthenticated {
            signOut()
        }
    }
}
