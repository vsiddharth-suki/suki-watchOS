import Foundation

enum JWTPayloadDecoder {
    static func payload(from jwt: String) -> [String: Any]? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var base64 = String(parts[1])
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        base64 = base64.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }

    static func userInfo(from idToken: String?) -> OktaUserInfo? {
        guard let idToken, let payload = payload(from: idToken) else { return nil }
        return OktaUserInfo(
            userID: payload["userID"] as? String,
            organizationID: payload["organizationID"] as? String,
            email: payload["email"] as? String ?? payload["sub"] as? String,
            sub: payload["sub"] as? String,
            displayName: displayName(from: payload)
        )
    }

    private static func displayName(from payload: [String: Any]) -> String? {
        if let name = payload["name"] as? String, !name.isEmpty { return name }
        let given = (payload["given_name"] as? String) ?? (payload["firstName"] as? String)
        let family = (payload["family_name"] as? String) ?? (payload["lastName"] as? String)
        let parts = [given, family]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}
