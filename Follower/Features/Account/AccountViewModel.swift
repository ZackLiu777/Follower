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
        case token
        case manual
    }
    private let accountRepo: AccountRepositoryProtocol
    private let syncEngine: SyncEngineProtocol
    private let apiClient: InstagramAPIClientProtocol
    private let tokenProvider: TokenProviderProtocol

    var accounts: [Account] = []
    var isLoading: Bool = false
    var isConnecting: Bool = false
    var isAddingAccount: Bool = false
    var addMode: AddMode = .token
    var username: String = ""
    var displayName: String = ""
    var errorMessage: String?
    var shouldDismiss: Bool = false

    init(
        accountRepo: AccountRepositoryProtocol,
        syncEngine: SyncEngineProtocol,
        apiClient: InstagramAPIClientProtocol,
        tokenProvider: TokenProviderProtocol
    ) {
        self.accountRepo = accountRepo
        self.syncEngine = syncEngine
        self.apiClient = apiClient
        self.tokenProvider = tokenProvider
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

    /// 用 Instagram access token 连接账号
    func connectWithToken(_ token: String) async {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter a valid access token."
            return
        }

        isConnecting = true
        defer { isConnecting = false }

        do {
            // 1. 验证 token：调 /me
            let user = try await apiClient.fetchProfile(accessToken: trimmed)

            // 2. 创建 Account（真实数据）
            let account = Account(
                platform: .instagram,
                username: user.username,
                displayName: user.name ?? user.username,
                authState: .authorized,
                createdAt: Date(),
                updatedAt: Date()
            )
            let saved = try await accountRepo.insert(account)
            guard let accountId = saved.id else {
                errorMessage = "Failed to save account."
                return
            }

            // 3. Token 存 Keychain
            try await tokenProvider.storeToken(accountId: accountId, accessToken: trimmed)

            // 4. 首次全量同步
            do {
                _ = try await syncEngine.sync(accountId: accountId)
            } catch {
                // 同步失败不阻塞（可能是网络问题）
            }

            await loadAccounts()
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
