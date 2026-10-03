import Foundation

enum APIError: LocalizedError {
    case unauthorized
    case invalidURL
    case server(Int, String)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Session expired. Please sign in again."
        case .invalidURL: return "Invalid request URL."
        case .server(let code, let body): return "Server error (\(code)): \(body)"
        case .decoding(let error): return "Failed to parse response: \(error.localizedDescription)"
        }
    }
}

enum APIHost {
    case v2
    case gateway
}

struct APIRequestDescriptor {
    let host: APIHost
    let path: String
    let method: String
    var query: [String: String] = [:]
    /// When set, used instead of `query` (e.g. repeated `note_ids`).
    var queryItems: [URLQueryItem]?
    var body: Data?
}

final class APIClient {
    private let session: URLSession
    private let sessionStore: SessionStore

    init(session: URLSession = .shared, sessionStore: SessionStore = .shared) {
        self.session = session
        self.sessionStore = sessionStore
    }

    func send<T: Decodable>(_ descriptor: APIRequestDescriptor, as type: T.Type) async throws -> T {
        let request = try buildRequest(descriptor)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.server(-1, "No HTTP response")
        }
        if http.statusCode == 401 {
            throw APIError.unauthorized
        }
        guard (200 ... 299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.server(http.statusCode, body)
        }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    func send(_ descriptor: APIRequestDescriptor) async throws {
        let request = try buildRequest(descriptor)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.server(-1, "No HTTP response")
        }
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200 ... 299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.server(http.statusCode, body)
        }
        _ = data
    }

    private func buildRequest(_ descriptor: APIRequestDescriptor) throws -> URLRequest {
        let host = descriptor.host == .v2 ? APIConfiguration.v2Host : APIConfiguration.gatewayHost
        var components = URLComponents()
        components.scheme = APIConfiguration.scheme
        components.host = host
        components.path = descriptor.path
        if let queryItems = descriptor.queryItems {
            components.queryItems = queryItems
        } else if !descriptor.query.isEmpty {
            components.queryItems = descriptor.query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = descriptor.method
        request.httpBody = descriptor.body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(APIConfiguration.userAgentJSON, forHTTPHeaderField: "x-suki-user-agent")
        if let token = sessionStore.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}
