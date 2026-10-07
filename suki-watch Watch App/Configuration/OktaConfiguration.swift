import Foundation

enum OktaConfiguration {
    static var issuer: String { AppEnvironment.current.oktaIssuer }
    static var clientId: String { AppEnvironment.current.oktaClientId }
    static let scope = "openid profile offline_access email"
}
