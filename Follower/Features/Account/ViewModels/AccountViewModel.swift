//
//  AccountViewModel.swift
//  Follower
//
//  账号管理 ViewModel — Instagram token 连接 / 撤销 / 删除。
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class AccountViewModel {
    enum AddMode: String, Hashable {
        case oauth
        case token
        case manual
    }
    private let accountRepo: AccountRepositoryProtocol
    private let syncEngine: SyncEngineProtocol
    private let apiClient: InstagramAPIClientProtocol
    private let tokenProvider: TokenProviderProtocol
    private let oauthService: InstagramOAuthService

    var accounts: [Account] = []
    var isLoading: Bool = false
    var isConnecting: Bool = false
    var isAddingAccount: Bool = false
    var addMode: AddMode = .oauth
    var clientId: String = ""
    var clientSecret: String = ""
    var redirectURI: String = ""
    var username: String = ""
    var displayName: String = ""
    var errorMessage: String?
    var shouldDismiss: Bool = false

    init(
        accountRepo: AccountRepositoryProtocol,
        syncEngine: SyncEngineProtocol,
        apiClient: InstagramAPIClientProtocol,
        tokenProvider: TokenProviderProtocol,
        oauthService: InstagramOAuthService = InstagramOAuthService()
    ) {
        self.accountRepo = accountRepo
        self.syncEngine = syncEngine
        self.apiClient = apiClient
        self.tokenProvider = tokenProvider
        self.oauthService = oauthService
    }

    // MARK: - Public

    func loadAccounts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            accounts = try await accountRepo.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 通过 Instagram OAuth 登录（ASWebAuthenticationSession）
    func connectWithInstagram(clientId: String, clientSecret: String, redirectURI: String) async {
        let config = InstagramOAuthConfig(
            clientId: clientId, clientSecret: clientSecret,
            redirectURI: redirectURI, scopes: InstagramOAuthConfig.defaultScopes
        )
        isConnecting = true
        defer { isConnecting = false }
        do {
            let result = try await oauthService.authorize(config: config)
            try await createAccountAndSync(token: result.accessToken, username: result.username)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 用 Instagram access token 连接账号（手动粘贴 token）
    func connectWithToken(_ token: String) async {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter a valid access token."
            return
        }

        isConnecting = true
        defer { isConnecting = false }

        do {
            let user = try await apiClient.fetchProfile(accessToken: trimmed)
            try await createAccountAndSync(token: trimmed, username: user.username, accountType: user.accountType)
            NotificationCenter.default.post(name: .accountCreated, object: nil)
            shouldDismiss = true
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func revokeAccount(_ id: Int64) async {
        do {
            try? await tokenProvider.deleteToken(accountId: id)
            var account = try await accountRepo.fetch(id: id)
            account?.authState = .revoked
            if var updated = account {
                try await accountRepo.update(updated)
            }
            await loadAccounts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteAccount(_ id: Int64) async {
        do {
            try? await tokenProvider.deleteToken(accountId: id)
            try await accountRepo.delete(id: id)
            await loadAccounts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private helpers

    private func createAccountAndSync(token: String, username: String, accountType: String? = nil) async throws {
        let account = Account(
            platform: .instagram,
            username: username,
            displayName: username,
            authState: .authorized,
            accountType: accountType,
            createdAt: Date(), updatedAt: Date()
        )
        var accountId: Int64
        // 检查是否已存在
        let allAccounts: [Account]
        do {
            allAccounts = try await accountRepo.fetchAll()
        } catch {
            errorMessage = "Database error: \(error.localizedDescription)"
            return
        }
        if let existing = allAccounts.first(where: { $0.platform == .instagram && $0.username == username }),
           let existingId = existing.id {
            accountId = existingId
            var updated = existing
            updated.authState = .authorized
            if let accountType { updated.accountType = accountType }
            updated.updatedAt = Date()
            try await accountRepo.update(updated)
        } else {
            do {
                _ = try await accountRepo.insert(account)
            } catch {
                errorMessage = "Insert error: \(error.localizedDescription)"
                return
            }
            let refreshed: [Account]
            do {
                refreshed = try await accountRepo.fetchAll()
            } catch {
                errorMessage = "Fetch error: \(error.localizedDescription)"
                return
            }
            guard let found = refreshed.first(where: { $0.username == username }),
                  let id = found.id else {
                errorMessage = "Account persisted but fetch returned \(refreshed.count) accounts, none matching '\(username)'"
                return
            }
            accountId = id
        }
        try await tokenProvider.storeToken(accountId: accountId, accessToken: token)
        do {
            _ = try await syncEngine.sync(accountId: accountId)
        } catch { }
        await loadAccounts()
        shouldDismiss = true
    }

    /// 用 Mock 数据连接测试账号 — 创建 isTest 账号 + 哨兵 token + 全链路 mock 同步。
    /// 分派契约：哨兵 token（mock://）→ APIClientResolver 分派到 MockInstagramAPIClient，
    /// 真实 API 从未被调用；数据覆盖 730 天序列 / 25 条媒体 / 评论 / 地域分布。
    func connectTestAccount() async {
        isConnecting = true
        defer { isConnecting = false }
        do {
            // 允许多个测试账号：序号命名避免与已有账号冲突
            let all = (try? await accountRepo.fetchAll()) ?? []
            let testCount = all.filter { $0.isTest }.count
            let username = testCount == 0 ? "test.user" : "test.user.\(testCount + 1)"

            let account = Account(
                platform: .instagram,
                username: username,
                displayName: "Test User \(testCount + 1)",
                authState: .authorized,
                accountType: "BUSINESS", // BUSINESS → 解锁评论管理入口
                isTest: true,
                createdAt: Date(), updatedAt: Date()
            )
            let inserted = try await accountRepo.insert(account)
            guard let accountId = inserted.id else {
                errorMessage = "测试账号创建失败"
                return
            }
            // 哨兵 token：RoutingTokenProvider 对测试账号跳过 Keychain（no-op），
            // 连接流程永不因 Keychain 失败；分派由 APIClientResolver 按 token 值决定
            try await tokenProvider.storeToken(
                accountId: accountId,
                accessToken: MockInstagramAPIClient.sentinelToken
            )
            _ = try? await syncEngine.sync(accountId: accountId)
            NotificationCenter.default.post(name: .accountCreated, object: nil)
            await loadAccounts()
            shouldDismiss = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 手动创建测试账号（无 token，用于验证空状态 UI）
    func addAccount() async {
        guard !username.isEmpty, !displayName.isEmpty else { return }

        isLoading = true
        defer { isLoading = false; isAddingAccount = false }

        do {
            let account = Account(
                platform: .instagram,
                username: username,
                displayName: displayName,
                authState: .authorized,
                createdAt: Date(),
                updatedAt: Date()
            )
            _ = try await accountRepo.insert(account)
            username = ""
            displayName = ""
            await loadAccounts()
            NotificationCenter.default.post(name: .accountCreated, object: nil)
            shouldDismiss = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
