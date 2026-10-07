import Foundation

enum APIConfiguration {
    static var v2Host: String { AppEnvironment.current.v2Host }
    static var gatewayHost: String { AppEnvironment.current.gatewayHost }
    static let scheme = "https"

    static var userAgentJSON: String {
        """
        {"client":"suki-watch","platform":"watchOS","version":"1.0"}
        """
    }
}
