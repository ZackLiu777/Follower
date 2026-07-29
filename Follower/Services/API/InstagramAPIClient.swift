//
//  InstagramAPIClient.swift
//  Follower
//
//  Instagram Graph API HTTP 客户端。
//  - URLSession + async/await，零第三方依赖
//  - Instagram Login 路径：graph.instagram.com
//

import Foundation

// MARK: - Protocol

protocol InstagramAPIClientProtocol: Sendable {
    func fetchProfile(accessToken: String) async throws -> IGUser
    func fetchInsights(accessToken: String, metrics: [String], period: String) async throws -> [IGInsightValue]
    func fetchMedia(accessToken: String, limit: Int) async throws -> [IGMedia]
}

// MARK: - Client

final class InstagramAPIClient: InstagramAPIClientProtocol {

    private let baseURL = "https://graph.instagram.com"
    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
    }

    // MARK: - Public API

    func fetchProfile(accessToken: String) async throws -> IGUser {
        let url = "\(baseURL)/me?fields=id,username,name,followers_count,follows_count,media_count&access_token=\(accessToken)"
        #if DEBUG
        print("[APIClient] fetchProfile URL length: \(url.count), token length: \(accessToken.count)")
        #endif
        return try await get(url)
    }

    func fetchInsights(accessToken: String, metrics: [String], period: String) async throws -> [IGInsightValue] {
        let metricStr = metrics.joined(separator: ",")
        let url = "\(baseURL)/me/insights?metric=\(metricStr)&period=\(period)&access_token=\(accessToken)"
        let response: IGInsightsResponse = try await get(url)
        return response.data ?? []
    }

    func fetchMedia(accessToken: String, limit: Int = 25) async throws -> [IGMedia] {
        let url = "\(baseURL)/me/media?fields=id,caption,media_type,permalink,timestamp,like_count,comments_count&limit=\(limit)&access_token=\(accessToken)"
        let response: IGMediaResponse = try await get(url)
        return response.data ?? []
    }

    // MARK: - HTTP

    private func get<T: Decodable>(_ urlString: String) async throws -> T {
        let data = try await request(urlString)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }

    private func request(_ urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL(urlString)
        }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: req)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw APIError.networkUnavailable
            case .timedOut:
                throw APIError.timeout
            default:
                throw APIError.unknown(error)
            }
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.httpError(statusCode: -1, body: "Non-HTTP response")
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw APIError.unauthorized
        case 429:
            throw APIError.rateLimited
        default:
            let body = String(data: data, encoding: .utf8)
            throw APIError.httpError(statusCode: httpResponse.statusCode, body: body)
        }
    }
}

// MARK: - APIError

enum APIError: Error, LocalizedError {
    case networkUnavailable
    case timeout
    case invalidURL(String)
    case httpError(statusCode: Int, body: String?)
    case unauthorized
    case rateLimited
    case decodingFailed(Error)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable: return "No internet connection."
        case .timeout: return "Request timed out."
        case .invalidURL(let url): return "Invalid URL: \(url)"
        case .httpError(let code, let body): return "HTTP \(code): \(body ?? "")"
        case .unauthorized: return "Invalid or expired access token."
        case .rateLimited: return "API rate limit exceeded. Try again later."
        case .decodingFailed(let error): return "Decoding failed: \(error.localizedDescription)"
        case .unknown(let error): return error.localizedDescription
        }
    }
}
