import Foundation

enum APIError: Error, LocalizedError {
    case invalidResponse
    case httpError(Int, Data)
    case decodingError(Error)
    case noToken

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid server response"
        case .httpError(let code, _): return "HTTP error \(code)"
        case .decodingError(let err): return "Decoding failed: \(err.localizedDescription)"
        case .noToken: return "Not authenticated"
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    private let baseURL = URL(string: "https://comuginator.com/")!
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)

        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        encoder = JSONEncoder()
    }

    func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        requiresAuth: Bool = true,
        familyId: String? = nil
    ) async throws -> T {
        // Not appendingPathComponent: paths may carry query strings ("…?scope=all")
        // and that API would percent-encode the "?".
        guard let url = URL(string: path, relativeTo: baseURL) else { throw APIError.invalidResponse }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth {
            guard let token = SessionStore.shared.token else { throw APIError.noToken }
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Every request carries the active family context; with multi-family
        // memberships the server otherwise resolves the device's oldest family.
        // An explicit familyId (cross-family probing) wins over the default.
        if let effectiveFamilyId = familyId ?? SessionStore.shared.familyId {
            req.setValue(effectiveFamilyId, forHTTPHeaderField: "X-Family-Id")
        }

        if let body {
            req.httpBody = try encoder.encode(body)
        }

        print("[API] \(method) \(req.url?.absoluteString ?? "")")
        if let body = req.httpBody { print("[API] Body: \(String(data: body, encoding: .utf8) ?? "")") }

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        let rawResponse = String(data: data, encoding: .utf8) ?? ""
        print("[API] → \(http.statusCode) | \(rawResponse.prefix(500))")
        if !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            print("[API] Error body: \(body)")
            throw APIError.httpError(http.statusCode, data)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            print("[API] Decode error: \(error)")
            print("[API] Raw response: \(body)")
            throw APIError.decodingError(error)
        }
    }

    func upload<T: Decodable>(
        path: String,
        imageData: Data,
        fileName: String,
        mimeType: String = "image/jpeg"
    ) async throws -> T {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"

        guard let token = SessionStore.shared.token else { throw APIError.noToken }
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let familyId = SessionStore.shared.familyId {
            req.setValue(familyId, forHTTPHeaderField: "X-Family-Id")
        }

        let boundary = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var bodyData = Data()
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        bodyData.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        bodyData.append(imageData)
        bodyData.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = bodyData

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.httpError(http.statusCode, data)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
