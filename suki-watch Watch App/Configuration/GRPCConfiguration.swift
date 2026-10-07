import Foundation

enum GRPCConfiguration {
    static var host: String { AppEnvironment.current.grpcHost }
    static let port = 443
}
