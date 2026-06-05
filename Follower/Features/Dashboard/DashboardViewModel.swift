//
//  DashboardViewModel.swift
//  Follower
//
//  Dashboard 页面 ViewModel。
//  负责展示基础统计数据：
//  - 粉丝数、关注数、帖子数
//  - 基础互动数（点赞、评论、分享）
//  - 互动率
//  - 主页访问量
//

import Foundation
import Combine
import SwiftUI
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    // MARK: - Dependencies

    private let snapshotRepo: SnapshotRepositoryProtocol
    private let accountRepo: AccountRepositoryProtocol
    private let syncEngine: SyncEngineProtocol

    // MARK: - Published State

    @Published var latestSnapshot: Snapshot?
    @Published var accounts: [Account] = []
    @Published var selectedAccountId: Int64?
    @Published var isLoading: Bool = false
    @Published var isSyncing: Bool = false
    @Published var errorMessage: String?

    // MARK: - Init

    init(
        snapshotRepo: SnapshotRepositoryProtocol,
        accountRepo: AccountRepositoryProtocol,
        syncEngine: SyncEngineProtocol
    ) {
        self.snapshotRepo = snapshotRepo
        self.accountRepo = accountRepo
        self.syncEngine = syncEngine
    }

    // MARK: - Public

    func loadAccounts() async {
        do {
            accounts = try await accountRepo.fetchAll()
            if selectedAccountId == nil {
                selectedAccountId = accounts.first?.id
            }
            await loadLatestSnapshot()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadLatestSnapshot() async {
        guard let accountId = selectedAccountId else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            latestSnapshot = try await snapshotRepo.latest(accountId: accountId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sync() async {
        guard let accountId = selectedAccountId else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            _ = try await syncEngine.sync(accountId: accountId)
            await loadLatestSnapshot()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectAccount(_ id: Int64) {
        selectedAccountId = id
        Task { await loadLatestSnapshot() }
    }
}
