//
//  AccountViewModel.swift
//  Follower
//
//  账号管理 ViewModel。
//  负责：
//  - 登录与账号绑定
//  - 账号列表管理
//  - 撤销授权
//  Alpha 阶段使用模拟登录。
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class AccountViewModel: ObservableObject {
    // MARK: - Dependencies

    private let accountRepo: AccountRepositoryProtocol
    private let syncEngine: SyncEngineProtocol

    // MARK: - Published State

    @Published var accounts: [Account] = []
    @Published var isAddingAccount: Bool = false
    @Published var selectedPlatform: Platform = .instagram
    @Published var username: String = ""
    @Published var displayName: String = ""

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var shouldDismiss: Bool = false

    // MARK: - Init

    init(
        accountRepo: AccountRepositoryProtocol,
        syncEngine: SyncEngineProtocol
    ) {
        self.accountRepo = accountRepo
        self.syncEngine = syncEngine
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

    /// 添加账号（Alpha 阶段模拟绑定）
    func addAccount() async {
        guard !username.isEmpty, !displayName.isEmpty else {
            errorMessage = loc(L10n.Account.requiredFields)
            return
        }

        isLoading = true
        defer {
            isLoading = false
            isAddingAccount = false
        }

        do {
            let account = Account(
                platform: selectedPlatform,
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
            shouldDismiss = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 撤销授权（用户权利）
    func revokeAccount(_ id: Int64) async {
        do {
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

    /// 删除账号
    func deleteAccount(_ id: Int64) async {
        do {
            try await accountRepo.delete(id: id)
            await loadAccounts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
