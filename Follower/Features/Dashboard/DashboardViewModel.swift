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
    // Gamma: Premium data
    @Published var engagementScore: ScoringResult?
    @Published var activityResult: ActivityResult?
    @Published var retentionResult: RetentionResult?
    @Published var topGeoRegion: GeoRegion?
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
            await loadPremiumInsights(accountId: accountId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Gamma: Premium analysis using available snapshot data
    func loadPremiumInsights(accountId: Int64) async {
        guard let snapshot = latestSnapshot else { return }
        // Engagement quality from current snapshot
        let scoring = ScoringService()
        engagementScore = await scoring.scoreEngagement(snapshots: [snapshot])

        // Load recent snapshots for trend analysis
        if let snapshots = try? await snapshotRepo.fetch(accountId: accountId, from: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(), to: Date()), !snapshots.isEmpty {
            let retention = RetentionAnalysisService()
            retentionResult = await retention.analyze(snapshots: snapshots)
        }

        // Geo distribution (mock)
        let geo = GeoDistributionService()
        let dist = await geo.fetchDistribution(accountId: accountId)
        topGeoRegion = dist.topRegion
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
