//
//  TokenProvider.swift
//  Follower
//
//  Instagram access token 管理（Keychain 存取）。
//  actor 隔离保证线程安全，按 accountId 索引。
//

import Foundation
import Security

// MARK: - Protocol

protocol TokenProviderProtocol: Sendable {
    func storeToken(accountId: Int64, accessToken: String) async throws
    func getToken(accountId: Int64) async throws -> String
    func deleteToken(accountId: Int64) async throws
}

// MARK: - TokenProvider

final actor TokenProvider: TokenProviderProtocol {

    private let service = "com.follower.instagram"

    // MARK: - Public

    func storeToken(accountId: Int64, accessToken: String) async throws {
        let data = Data(accessToken.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: "ig_token_\(accountId)",
        ]

        // 先删旧值
        SecItemDelete(query as CFDictionary)

        // 插入新值
        var addQuery = query
        addQuery[kSecValueData] = data
        addQuery[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw TokenError.keychainError(status: Int(status))
        }
    }

    func getToken(accountId: Int64) async throws -> String {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: "ig_token_\(accountId)",
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data, let token = String(data: data, encoding: .utf8) else {
            if status == errSecItemNotFound {
                throw TokenError.tokenNotFound
            }
            throw TokenError.keychainError(status: Int(status))
        }

        return token
    }

    func deleteToken(accountId: Int64) async throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: "ig_token_\(accountId)",
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - TokenError

enum TokenError: Error, LocalizedError {
    case tokenNotFound
    case keychainError(status: Int)

    var errorDescription: String? {
        switch self {
        case .tokenNotFound: return "No access token found. Please connect Instagram first."
        case .keychainError(let s): return "Keychain error (status: \(s))."
        }
    }
}
