//
//  DashboardViewModel.swift
//  Follower
//
//  Lambda: Hero 粉丝 + 次要指标 + 帖子列表 + Premium insights。

import Foundation
import SwiftUI
import Combine

/// Dashboard 的 ViewModel：管理账户选择、快照数据、增量计算、帖子与 Premium Mock 数据
@MainActor
final class DashboardViewModel: ObservableObject {
    /// Snapshot 数据仓库
    private let snapshotRepo: SnapshotRepositoryProtocol
    /// 账户数据仓库
    private let accountRepo: AccountRepositoryProtocol
    /// 同步引擎
    private let syncEngine: SyncEngineProtocol

    // MARK: - Published: 核心状态

    /// 最新 Snapshot
    @Published var latestSnapshot: Snapshot?
    /// 所有已连接账户
    @Published var accounts: [Account] = []
    /// 当前选中账户 ID
    @Published var selectedAccountId: Int64?
    /// 加载中标记
    @Published var isLoading: Bool = false
    /// 同步中标记
    @Published var isSyncing: Bool = false
    /// 错误消息（非 nil 时展示 ErrorBanner）
    @Published var errorMessage: String?

    // MARK: - Published: Hero 指标

    /// 粉丝数环比变化（7 天）
    @Published var followerDelta: Int = 0
    /// 粉丝数环比百分比
    @Published var followerDeltaPercent: Double = 0
    /// 粉丝趋势 Mini 折线图数据
    @Published var sparklineData: [Double] = []

    // MARK: - Published: 次要指标

    /// 互动率环比变化
    @Published var engagementDelta: Double = 0
    /// Reach 环比变化
    @Published var reachDelta: Int = 0
    /// 帖子数环比变化
    @Published var postsDelta: Int = 0

    // MARK: - Published: 帖子列表

    /// 最近帖子（Mock）
    @Published var recentPosts: [MockPost] = []

    // MARK: - Published: Premium Mock 数据

    /// 取关用户列表（Mock）
    @Published var unfollowList: [MockFollower] = []
    /// 推荐最佳发帖时间（Mock）
    @Published var bestPostingTime: String = ""
    /// 内容策略建议（Mock）
    @Published var contentTip: String = ""
    /// 预测下月粉丝数（Mock）
    @Published var predictedFollowers: Int = 0

    /// 初始化：注入三个核心依赖
    init(snapshotRepo: SnapshotRepositoryProtocol, accountRepo: AccountRepositoryProtocol, syncEngine: SyncEngineProtocol) {
        self.snapshotRepo = snapshotRepo
        self.accountRepo = accountRepo
        self.syncEngine = syncEngine
    }

    /// 加载账户列表并自动选中第一个，随后加载全部数据
    func loadAccounts() async {
        do {
            accounts = try await accountRepo.fetchAll()
            if selectedAccountId == nil { selectedAccountId = accounts.first?.id }
            await loadAllData()
        } catch { errorMessage = error.localizedDescription }
    }

    /// 加载当前选中账户的 Snapshot、增量、帖子与 Premium 数据
    func loadAllData() async {
        guard let accountId = selectedAccountId else { return }
        isLoading = true; defer { isLoading = false }
        do {
            latestSnapshot = try await snapshotRepo.latest(accountId: accountId)
            await computeDeltas(accountId: accountId)
            await loadPosts()
            await loadPremiumInsights()
        } catch { errorMessage = error.localizedDescription }
    }

    /// 触发同步引擎拉取最新数据，完成后刷新 UI
    func sync() async {
        guard let accountId = selectedAccountId else { return }
        isSyncing = true; defer { isSyncing = false }
        do {
            _ = try await syncEngine.sync(accountId: accountId)
            await loadAllData()
        } catch { errorMessage = error.localizedDescription }
    }

    /// 切换选中账户并重新加载数据
    func selectAccount(_ id: Int64) { selectedAccountId = id; Task { await loadAllData() } }

    // MARK: - Private

    /// 计算 7 天环比的 Hero 与次要指标增量
    private func computeDeltas(accountId: Int64) async {
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        guard let snapshots = try? await snapshotRepo.fetch(accountId: accountId, from: weekAgo, to: now),
              let current = latestSnapshot else { return }

        sparklineData = snapshots.map { Double($0.followersCount) }

        if let first = snapshots.first {
            followerDelta = current.followersCount - first.followersCount
            followerDeltaPercent = first.followersCount > 0 ? Double(followerDelta) / Double(first.followersCount) * 100 : 0
            engagementDelta = current.engagementRate - first.engagementRate
            reachDelta = current.totalViews - first.totalViews
            postsDelta = current.mediaCount - first.mediaCount
        }
    }

    /// 加载 Mock 帖子列表
    private func loadPosts() async {
        recentPosts = MockPostGenerator().generate(count: 5)
    }

    /// 加载 Premium Mock 数据：取关列表、最佳时间、策略建议、预测粉丝
    private func loadPremiumInsights() async {
        unfollowList = MockFollowerListGenerator().generateUnfollows(count: 4)
        bestPostingTime = ["Wed 7PM", "Mon 8PM", "Sat 11AM", "Fri 6PM"].randomElement()!
        contentTip = ["Carousel posts get 2.3x more engagement", "Videos under 30s perform best", "Post 3-5 times per week for optimal growth"].randomElement()!
        predictedFollowers = (latestSnapshot?.followersCount ?? 1000) + Int.random(in: 50...500)
    }
}
