import Foundation

/// Arbitrary JSON, for record payloads. Integers and doubles stay distinct so
/// epoch-millisecond stamps and counts round-trip exactly.
public enum JSONValue: Codable, Hashable, Sendable {
    case null
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Int64.self) { self = .int(v) }
        else if let v = try? c.decode(Double.self) { self = .double(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }

    /// Converts a record to its JSON payload.
    static func encoding<T: Encodable>(_ value: T) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value))
    }

    /// Decodes a record from its JSON payload.
    func decoded<T: Decodable>(as type: T.Type) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(self))
    }
}

// Wire types of the server's /api/v2 sync API (backend/src/sync.rs).

struct OutgoingChange: Encodable, Sendable {
    var entity: String
    var id: String
    var updatedAt: Int64
    var deleted: Bool
    var data: JSONValue?
}

struct PushRequest: Encodable, Sendable {
    var changes: [OutgoingChange]
}

struct StaleChange: Decodable, Sendable {
    var entity: String
    var id: String
    var updatedAt: Int64
}

struct PushResponse: Decodable, Sendable {
    var storeId: String
    var serverSeq: Int64
    var accepted: Int
    var stale: [StaleChange]
}

public struct PulledChange: Decodable, Sendable, Equatable {
    public var entity: String
    public var id: String
    public var updatedAt: Int64
    public var deleted: Bool
    public var data: JSONValue?
    public var seq: Int64
}

struct PullResponse: Decodable, Sendable {
    var storeId: String
    var changes: [PulledChange]
    var nextSince: Int64
    var hasMore: Bool
}

public struct ServerStatus: Decodable, Sendable, Equatable {
    public var storeId: String
    public var serverSeq: Int64
    public var records: Int
    public var countsByEntity: [String: Int]
}

private struct ErrorBody: Decodable {
    var error: String
}

// MARK: - Client

/// Where and how to reach the sync server.
public struct SyncConfiguration: Sendable, Equatable {
    /// e.g. https://gym.4rr.xyz — the app's root, without /api/v2.
    public var baseURL: URL
    public var token: String

    public init(baseURL: URL, token: String) {
        self.baseURL = baseURL
        self.token = token
    }
}

/// Sends HTTP requests; tests substitute a fake.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

public enum SyncError: Error, Equatable, Sendable {
    /// No server URL or token configured on the phone.
    case missingConfiguration
    /// The server couldn't be reached.
    case offline
    case tokenRejected
    /// The server runs without SYNC_TOKEN.
    case serverNotConfigured
    /// Something other than the sync API answered, e.g. a Cloudflare Access
    /// login page.
    case notSyncServer(status: Int)
    case server(status: Int, message: String)
    case unexpectedResponse(String)

    /// Status-line copy (styleguide §28: direct, uppercase).
    public var message: String {
        switch self {
        case .missingConfiguration: "SET THE SERVER URL AND TOKEN"
        case .offline: "OFFLINE"
        case .tokenRejected: "SYNC FAILED — TOKEN REJECTED"
        case .serverNotConfigured: "SYNC FAILED — SERVER HAS NO SYNC TOKEN"
        case .notSyncServer: "SYNC FAILED — NOT A TRAIN TOGETHER SERVER (CLOUDFLARE ACCESS?)"
        case .server(let status, _): "SYNC FAILED — SERVER ERROR \(status)"
        case .unexpectedResponse: "SYNC FAILED — UNEXPECTED RESPONSE"
        }
    }

    /// Worth retrying later without the user changing anything.
    var isTransient: Bool {
        switch self {
        case .offline, .server: true
        case .missingConfiguration, .tokenRejected, .serverNotConfigured, .notSyncServer, .unexpectedResponse: false
        }
    }
}

struct SyncClient: Sendable {
    let configuration: SyncConfiguration
    let transport: any HTTPTransport

    func status() async throws -> ServerStatus {
        try await send("GET", "sync/status")
    }

    func push(_ changes: [OutgoingChange]) async throws -> PushResponse {
        try await send("POST", "sync/push", body: try JSONEncoder().encode(PushRequest(changes: changes)))
    }

    func pull(since: Int64, limit: Int) async throws -> PullResponse {
        try await send("GET", "sync/pull", query: [
            URLQueryItem(name: "since", value: String(since)),
            URLQueryItem(name: "limit", value: String(limit)),
        ])
    }

    private func send<T: Decodable>(
        _ method: String, _ path: String, query: [URLQueryItem] = [], body: Data? = nil
    ) async throws -> T {
        var url = configuration.baseURL.appending(path: "api/v2/\(path)")
        if !query.isEmpty { url.append(queryItems: query) }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        request.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch is URLError {
            throw SyncError.offline
        }

        let contentType = response.value(forHTTPHeaderField: "Content-Type") ?? ""
        guard contentType.contains("application/json") else {
            throw SyncError.notSyncServer(status: response.statusCode)
        }
        switch response.statusCode {
        case 200..<300:
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw SyncError.unexpectedResponse(String(describing: error))
            }
        case 401:
            throw SyncError.tokenRejected
        case 503:
            throw SyncError.serverNotConfigured
        default:
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error ?? ""
            throw SyncError.server(status: response.statusCode, message: message)
        }
    }
}
