import Foundation

enum APIConfiguration {
    static let v2Host = "web-api-v2.suki-stage.com"
    static let gatewayHost = "gateway.suki-stage.com"
    static let scheme = "https"

    static var userAgentJSON: String {
        """
        {"client":"suki-watch","platform":"watchOS","version":"1.0"}
        """
    }
}
