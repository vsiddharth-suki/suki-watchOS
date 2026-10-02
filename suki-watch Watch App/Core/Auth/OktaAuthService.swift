import Foundation

enum OktaAuthError: LocalizedError {
    case missingToken
    case missingUserInfo

    var errorDescription: String? {
        switch self {
        case .missingToken: return "No access token returned from Okta."
        case .missingUserInfo: return "Could not load user profile from Okta."
        }
    }
}

@MainActor
final class OktaAuthService {
    func signIn(username: String, password: String) async throws -> (OktaTokenResponse, OktaUserInfo) {
        let tokens = try await passwordGrant(username: username, password: password)
        let userInfo = try await fetchUserInfo(accessToken: tokens.accessToken)
        return (tokens, userInfo)
    }

    func mergeUserInfo(_ info: OktaUserInfo, idToken: String?) -> OktaUserInfo {
        guard let claims = JWTPayloadDecoder.userInfo(from: idToken) else { return info }
        return OktaUserInfo(
            userID: info.userID ?? claims.userID,
            organizationID: info.organizationID ?? claims.organizationID,
            email: info.email ?? claims.email,
            sub: info.sub ?? claims.sub,
            displayName: info.displayName ?? claims.displayName
        )
    }

    private func passwordGrant(username: String, password: String) async throws -> OktaTokenResponse {
        let url = URL(string: "\(OktaConfiguration.issuer)/v1/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "grant_type": "password",
            "username": username,
            "password": password,
            "scope": OktaConfiguration.scope,
            "client_id": OktaConfiguration.clientId
        ]
        request.httpBody = Self.formURLEncodedBody(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Authentication failed"
            throw APIError.server((response as? HTTPURLResponse)?.statusCode ?? -1, message)
        }
        return try JSONDecoder().decode(OktaTokenResponse.self, from: data)
    }

    /// Encodes values for `application/x-www-form-urlencoded` bodies.
    /// `+` must become `%2B` (unlike query strings where `+` means space).
    private static func formURLEncodedBody(_ parameters: [String: String]) -> Data {
        let pairs = parameters.map { key, value in
            "\(formURLEncode(key))=\(formURLEncode(value))"
        }
        return Data(pairs.joined(separator: "&").utf8)
    }

    private static func formURLEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: formURLComponentAllowed) ?? value
    }

    private static let formURLComponentAllowed: CharacterSet = {
        CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
    }()

    private func fetchUserInfo(accessToken: String) async throws -> OktaUserInfo {
        let url = URL(string: "\(OktaConfiguration.issuer)/v1/userinfo")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw OktaAuthError.missingUserInfo
        }
        return try JSONDecoder().decode(OktaUserInfo.self, from: data)
    }
}
