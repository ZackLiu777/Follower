//
//  InstagramOAuthService.swift
//  Follower
//
//  Instagram OAuth 2.0 — ASWebAuthenticationSession。
//  redirect URI: https://localhost/oauth/callback
//

import Foundation
import AuthenticationServices

// MARK: - Config

struct InstagramOAuthConfig: Sendable {
    let clientId: String
    let clientSecret: String
    let redirectURI: String
    let scopes: [String]

    static let defaultScopes = [
        "instagram_business_basic",
        "instagram_business_manage_comments",
        "instagram_business_content_publish",
        "instagram_business_manage_insights",
    ]

    var scopeString: String { scopes.joined(separator: ",") }

    var authorizeURL: URL? {
        // 2026 官方端点：www.instagram.com/oauth/authorize（api.instagram.com 的授权端点已迁移/停用；
        // token 交换仍走 api.instagram.com/oauth/access_token，见 exchangeCodeForToken）
        var comps = URLComponents(string: "https://www.instagram.com/oauth/authorize")
        comps?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopeString),
            URLQueryItem(name: "response_type", value: "code"),
        ]
        return comps?.url
    }
}

// MARK: - Result

struct InstagramOAuthResult: Sendable {
    let accessToken: String
    let username: String
    let userID: String
}

// MARK: - Service

final class InstagramOAuthService: NSObject, Sendable {

    func authorize(config: InstagramOAuthConfig) async throws -> InstagramOAuthResult {
        let code = try await requestAuthorizationCode(config: config)
        let (shortToken, userID) = try await exchangeCodeForToken(code: code, config: config)
        let longToken = try await exchangeForLongLivedToken(shortToken: shortToken)
        let username = try await fetchUsername(accessToken: longToken)
        return InstagramOAuthResult(accessToken: longToken, username: username, userID: userID)
    }

    // MARK: - Step 1: ASWebAuthenticationSession

    private func requestAuthorizationCode(config: InstagramOAuthConfig) async throws -> String {
        guard let authURL = config.authorizeURL else {
            throw APIError.invalidURL("Cannot build authorize URL")
        }

        // 从 redirect URI 提取 scheme（https）
        let scheme = URL(string: config.redirectURI)?.scheme ?? "https"

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: scheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let url = callbackURL,
                      let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: APIError.unauthorized)
                    return
                }
                continuation.resume(returning: code)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    // MARK: - Step 2: Code → short-lived token

    private func exchangeCodeForToken(code: String, config: InstagramOAuthConfig) async throws -> (String, String) {
        let url = URL(string: "https://api.instagram.com/oauth/access_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id": config.clientId,
            "client_secret": config.clientSecret,
            "grant_type": "authorization_code",
            "redirect_uri": config.redirectURI,
            "code": code,
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8)
            throw APIError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 400, body: bodyStr)
        }

        struct TR: Codable {
            let accessToken: String; let userId: Int64
            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"; case userId = "user_id"
            }
        }
        let resp = try JSONDecoder().decode(TR.self, from: data)
        return (resp.accessToken, "\(resp.userId)")
    }

    // MARK: - Step 3: Long-lived token

    private func exchangeForLongLivedToken(shortToken: String) async throws -> String {
        let urlString = "https://graph.instagram.com/access_token?grant_type=ig_exchange_token&access_token=\(shortToken)"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL(urlString) }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 400, body: nil)
        }
        struct LTR: Codable {
            let accessToken: String
            enum CodingKeys: String, CodingKey { case accessToken = "access_token" }
        }
        let resp = try JSONDecoder().decode(LTR.self, from: data)
        return resp.accessToken
    }

    // MARK: - Step 4: Fetch username

    private func fetchUsername(accessToken: String) async throws -> String {
        let urlString = "https://graph.instagram.com/me?fields=username&access_token=\(accessToken)"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL(urlString) }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 400, body: nil)
        }
        struct MR: Codable { let username: String? }
        let resp = try JSONDecoder().decode(MR.self, from: data)
        return resp.username ?? "instagram_user"
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension InstagramOAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // 从 SwiftUI 获取实际 window
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            return window
        }
        return ASPresentationAnchor()
    }
}
