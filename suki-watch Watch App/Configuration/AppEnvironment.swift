import Foundation

enum AppEnvironment: String, CaseIterable, Identifiable {
    case dev
    case test
    case stage
    case prod

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dev: return "Dev"
        case .test: return "Test"
        case .stage: return "Stage"
        case .prod: return "Prod"
        }
    }

    var logoImageName: String {
        switch self {
        case .dev: return "SukiDevLogo"
        case .test: return "SukiTestLogo"
        case .stage: return "SukiStageLogo"
        case .prod: return "SukiProdLogo"
        }
    }

    var v2Host: String {
        switch self {
        case .dev: return "web-api-v2.suki-dev.com"
        case .test: return "web-api-v2.suki-test.com"
        case .stage: return "web-api-v2.suki-stage.com"
        case .prod: return "web-api-v2.suki.ai"
        }
    }

    var gatewayHost: String {
        switch self {
        case .dev: return "gateway.suki-dev.com"
        case .test: return "gateway.suki-test.com"
        case .stage: return "gateway.suki-stage.com"
        case .prod: return "gateway.suki.ai"
        }
    }

    var grpcHost: String {
        switch self {
        case .dev: return "suki-server.suki-dev.com"
        case .test: return "suki-server.suki-test.com"
        case .stage: return "suki-server.suki-stage.com"
        case .prod: return "suki-server.suki.ai"
        }
    }

    var oktaIssuer: String {
        switch self {
        case .prod: return "https://suki-api.okta.com/oauth2/default"
        default: return "https://suki-sandbox.oktapreview.com/oauth2/default"
        }
    }

    var oktaClientId: String {
        switch self {
        case .dev: return "0oanlun3mwsufO4Qc0h7"
        case .test: return "0oa2lnelarv5RPJuB0h8"
        case .stage: return "0oa2osjkq7bnk3eQJ0h8"
        case .prod: return "0oa2u63czbTNfWfJV297"
        }
    }

    private static let storageKey = "suki.watch.selectedEnvironment"

    static var current: AppEnvironment {
        guard
            let raw = UserDefaults.standard.string(forKey: storageKey),
            let env = AppEnvironment(rawValue: raw)
        else {
            return .stage
        }
        return env
    }

    static func select(_ environment: AppEnvironment) {
        UserDefaults.standard.set(environment.rawValue, forKey: storageKey)
    }
}
