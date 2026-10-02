import Foundation

struct OktaTokenResponse: Codable {
    var accessToken: String
    var idToken: String?
    var tokenType: String?
    var expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case idToken = "id_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

struct OktaUserInfo: Decodable {
    var userID: String?
    var organizationID: String?
    var email: String?
    var sub: String?
    var displayName: String?

    enum CodingKeys: String, CodingKey {
        case userID = "userID"
        case organizationID = "organizationID"
        case email
        case sub
        case displayName = "name"
        case givenName = "given_name"
        case familyName = "family_name"
    }

    init(
        userID: String? = nil,
        organizationID: String? = nil,
        email: String? = nil,
        sub: String? = nil,
        displayName: String? = nil
    ) {
        self.userID = userID
        self.organizationID = organizationID
        self.email = email
        self.sub = sub
        self.displayName = displayName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decodeIfPresent(String.self, forKey: .userID)
        organizationID = try container.decodeIfPresent(String.self, forKey: .organizationID)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        sub = try container.decodeIfPresent(String.self, forKey: .sub)
        let name = try container.decodeIfPresent(String.self, forKey: .displayName)
        let given = try container.decodeIfPresent(String.self, forKey: .givenName)
        let family = try container.decodeIfPresent(String.self, forKey: .familyName)
        displayName = OktaUserInfo.combinedName(name: name, given: given, family: family)
    }

    private static func combinedName(name: String?, given: String?, family: String?) -> String? {
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let parts = [given, family]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}
