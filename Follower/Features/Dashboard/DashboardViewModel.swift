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
@Observable
final class DashboardViewModel {
    /// Snapshot 数据仓库
    private let snapshotRepo: SnapshotRepositoryProtocol
    /// 账户数据仓库
    private let accountRepo: AccountRepositoryProtocol
    /// 同步引擎
    private let syncEngine: SyncEngineProtocol
    /// Event 数据仓库（供 Premium 活跃度分析使用）
    private let eventRepo: EventRepositoryProtocol
    /// 趋势预测服务（Premium）
    private let predictionService: PredictionServiceProtocol
    /// 活跃度分析服务（Premium）
    private let activityService: ActivityAnalysisServiceProtocol
    /// 留存/流失分析服务（Premium）
    private let retentionService: RetentionAnalysisServiceProtocol
    /// 互动质量评分服务（Premium）
    private let scoringService: ScoringServiceProtocol
    /// 地域分布服务（Premium）
    private let geoService: GeoDistributionServiceProtocol
    /// 长期趋势对比服务（Premium）
    private let comparisonService: ComparisonServiceProtocol
    /// 本地 AI 分析服务（Premium）
    private let aiService: AIAnalysisServiceProtocol

    // MARK: - Published: 核心状态

    /// 最新 Snapshot
     var latestSnapshot: Snapshot?
    /// 所有已连接账户
     var accounts: [Account] = []
    /// 当前选中账户 ID
     var selectedAccountId: Int64?
    /// 加载中标记
     var isLoading: Bool = false
    /// 同步中标记
     var isSyncing: Bool = false
    /// 错误消息（非 nil 时展示 ErrorBanner）
     var errorMessage: String?

    // MARK: - Published: Hero 指标

    /// 粉丝数环比变化（7 天）
     var followerDelta: Int = 0
    /// 粉丝数环比百分比
     var followerDeltaPercent: Double = 0
    /// 粉丝趋势 Mini 折线图数据
     var sparklineData: [Double] = []

    // MARK: - Published: 次要指标

    /// 互动率环比变化
     var engagementDelta: Double = 0
    /// Reach 环比变化
     var reachDelta: Int = 0
    /// 帖子数环比变化
     var postsDelta: Int = 0

    // MARK: - Published: 帖子列表

    /// 最近帖子（Mock）
     var recentPosts: [MockPost] = []

    // MARK: - Published: Premium Real Insights

    /// 活跃度分析结果（Premium）
     var activityResult: ActivityResult?
    /// 留存/流失分析结果（Premium）
     var retentionResult: RetentionResult?
    /// 互动质量评分结果（Premium）
     var qualityScore: ScoringResult?
    /// 粉丝地域分布结果（Premium）
     var geoDistribution: GeoDistributionResult?
    /// 长期趋势对比结果（Premium）
     var comparisonResult: ComparisonResult?
    /// 粉丝数预测结果（Premium）
     var predictionResult: PredictionResult?
    /// AI 生成的摘要文本（Premium）
     var aiSummary: String = ""

    // MARK: - Published: Premium Mock 数据（向后兼容，保留 mock 回退）

    /// 取关用户列表（Mock）
     var unfollowList: [MockFollower] = []
    /// 推荐最佳发帖时间（Mock）
     var bestPostingTime: String = ""
    /// 内容策略建议（Mock）
     var contentTip: String = ""
    /// 预测下月粉丝数（Mock）
     var predictedFollowers: Int = 0

    /// 初始化：注入核心仓库、同步引擎与全部 Premium 分析服务
    init(
        snapshotRepo: SnapshotRepositoryProtocol,
        accountRepo: AccountRepositoryProtocol,
        syncEngine: SyncEngineProtocol,
        eventRepo: EventRepositoryProtocol,
        predictionService: PredictionServiceProtocol,
        activityService: ActivityAnalysisServiceProtocol,
        retentionService: RetentionAnalysisServiceProtocol,
        scoringService: ScoringServiceProtocol,
        geoService: GeoDistributionServiceProtocol,
        comparisonService: ComparisonServiceProtocol,
        aiService: AIAnalysisServiceProtocol
    ) {
        self.snapshotRepo = snapshotRepo
        self.accountRepo = accountRepo
        self.syncEngine = syncEngine
        self.eventRepo = eventRepo
        self.predictionService = predictionService
        self.activityService = activityService
        self.retentionService = retentionService
        self.scoringService = scoringService
        self.geoService = geoService
        self.comparisonService = comparisonService
        self.aiService = aiService
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

    /// 加载 Premium 数据：真实服务调用 + 向后兼容的 mock 回退
    private func loadPremiumInsights() async {
        guard let accountId = selectedAccountId else { return }

        // 快照数据 — 多个 Premium 服务共用
        let cutOff = Date().addingTimeInterval(-90 * 86_400)
        let snapshots = (try? await snapshotRepo.fetch(accountId: accountId, from: cutOff, to: Date())) ?? []
        let snap = latestSnapshot

        // 趋势预测（Linear Regression，30 天预测）
        if !snapshots.isEmpty {
            let dataPoints = snapshots.map { ($0.observedAt, Double($0.followersCount)) }
            predictionResult = await predictionService.predictLinear(dataPoints: dataPoints, daysAhead: 30)
        } else if let snap {
            let today = Date()
            let dataPoints = [(today, Double(snap.followersCount))]
            predictionResult = await predictionService.predictLinear(dataPoints: dataPoints, daysAhead: 30)
        }

        // 活跃度分析 — 基于 Event 时间分布
        if let events = try? await eventRepo.fetch(accountId: accountId, from: cutOff, to: Date()) {
            activityResult = await activityService.analyze(events: events, from: cutOff, to: Date())
        }

        // 留存/流失分析 — 基于 Snapshot 粉丝数变化
        if !snapshots.isEmpty {
            retentionResult = await retentionService.analyze(snapshots: snapshots)
        }

        // 互动质量评分 — 传入最新 Snapshot 做加权计算
        if let snap {
            qualityScore = await scoringService.scoreEngagement(snapshots: [snap])
        }

        // 长期趋势对比 — 当前周期 vs 空对比（Alpha 阶段仅有当期数据）
        comparisonResult = await comparisonService.compare(
            currentSnapshots: snapshots,
            previousSnapshots: [],
            extract: { $0.followersCount }
        )

        // 地域分布 — Mock 数据，预留真实 API 接口
        geoDistribution = await geoService.fetchDistribution(accountId: accountId)

        // AI 摘要 — 规则引擎分析 Snapshot 序列，提取 summary 类型洞察
        if !snapshots.isEmpty {
            let insights = await aiService.analyze(snapshots: snapshots)
            aiSummary = insights.first(where: { $0.type == .summary })?.detail ?? ""
        }

        // Mock 回退 — 保持向后兼容，现有 UI 继续工作
        unfollowList = MockFollowerListGenerator().generateUnfollows(count: 4)
        bestPostingTime = ["Wed 7PM", "Mon 8PM", "Sat 11AM", "Fri 6PM"].randomElement()!
        contentTip = ["Carousel posts get 2.3x more engagement", "Videos under 30s perform best", "Post 3-5 times per week for optimal growth"].randomElement()!
        predictedFollowers = (latestSnapshot?.followersCount ?? 1000) + Int.random(in: 50...500)
    }
}
