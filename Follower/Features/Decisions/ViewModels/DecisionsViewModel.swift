//
//  DecisionsViewModel.swift
//  Follower
//
//  Growth Decision Engine ViewModel — 加载数据、提取特征、评分、生成行动卡片。
//  与 Dashboard 同步：无账号 → 空状态；有账号无数据 → 等待同步；有数据 → 生成卡片。
//

import Foundation

// MARK: - DecisionSummary

/// 决策页 Hero 区摘要 — 由 ViewModel 从特征层结果组装（纯展示数据）
struct DecisionSummary: Sendable {
    /// 当前粉丝数
    let followers: Int
    /// 近 7 天涨粉（四舍五入）
    let growth7d: Int
    /// 近 7 天浏览增量（四舍五入）
    let views7d: Int
    /// 最近一次快照时间（数据新鲜度展示）
    let dataDate: Date?
}

@Observable
final class DecisionsViewModel {

    // MARK: - Dependencies

    private let snapshotRepo: SnapshotRepositoryProtocol
    private let metricRepo: MetricRepositoryProtocol
    private let accountRepo: AccountRepositoryProtocol
    private let mediaPostRepo: MediaPostRepositoryProtocol
    private let draftPostRepo: DraftPostRepositoryProtocol

    // MARK: - Published State

    /// 精选建议（相关性最优，≤4 条，类别互不重复）
    var cards: [ActionCard] = []
    /// 已连接账号列表（驱动空状态判断）
    var accounts: [Account] = []
    /// 是否有已连接账号
    var hasAccount: Bool { !accounts.isEmpty }
    /// 是否已同步过数据（有 snapshot 才显示卡片）
    var hasData: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?
    var selectedAccountId: Int64?
    /// Hero 区摘要（当前粉丝 / 7 日涨粉 / 7 日浏览 / 最佳时段）
    var summary: DecisionSummary?

    // MARK: - Initialization

    init(snapshotRepo: SnapshotRepositoryProtocol,
         metricRepo: MetricRepositoryProtocol,
         accountRepo: AccountRepositoryProtocol,
         mediaPostRepo: MediaPostRepositoryProtocol,
         draftPostRepo: DraftPostRepositoryProtocol) {
        self.snapshotRepo = snapshotRepo
        self.metricRepo = metricRepo
        self.accountRepo = accountRepo
        self.mediaPostRepo = mediaPostRepo
        self.draftPostRepo = draftPostRepo
    }

    // MARK: - Public Methods

    /// 页面首次加载 — 仅获取账号列表，不拉取数据（等 Dashboard sync 后用户手动刷新）
    func loadInitialAccount() async {
        do {
            accounts = try await accountRepo.fetchAll()
            if selectedAccountId == nil { selectedAccountId = accounts.first?.id }
        } catch { errorMessage = error.localizedDescription }
    }

    /// 完整流水线：拉取数据 → 提取特征 → 评分 → 生成建议
    @MainActor
    func refreshDecisions() async {
        guard let accountId = selectedAccountId else {
            hasData = false; cards = []; summary = nil
            print("[DecisionsVM] refreshDecisions — no account, cards: 0")
            return
        }
        isLoading = true; defer { isLoading = false }
        do {
            // 全量本地快照（v1.1：放开 90 天限制，用满用户长期累积的历史）
            let snapshots = try await snapshotRepo.fetchAll(accountId: accountId)
            let latest = try await snapshotRepo.latest(accountId: accountId)
            let followers = latest?.followersCount ?? 0
            // v1.1：帖子全量（类型占比/爆款/低互动分析用满本地历史）
            let posts = try await mediaPostRepo.fetchAll(accountId: accountId)

            // 周窗口指标（触达 / 主页浏览 / 平均赞 / 互动率）— 趋势信号用满本地历史
            var weekly: [MetricType: [Metric]] = [:]
            for type in [MetricType.reachEstimate, .profileViews, .averageLikes, .engagementTrend] {
                weekly[type] = (try? await metricRepo.fetch(
                    accountId: accountId, metricType: type, window: .week, limit: 365)) ?? []
            }
            let draftCount = ((try? await draftPostRepo.fetchAll()) ?? []).count

            hasData = !snapshots.isEmpty

            let health = FeatureExtractor.extractHealth(snapshots: snapshots, followers: followers)
            let contentPerf = FeatureExtractor.extractContentPerformance(posts: posts)
            let fatigue = FeatureExtractor.extractFatigue(performance: contentPerf)
            let impact = FeatureExtractor.extractImpact(snapshots: snapshots, posts: posts)
            let context = FeatureExtractor.extractContext(
                snapshots: snapshots, posts: posts, weeklyMetrics: weekly, draftCount: draftCount)
            let features = GrowthFeatures(contentPerformance: contentPerf, followerHealth: health,
                fatigueIndices: fatigue, impact: impact, context: context)

            let scores = ScoringEngine.score(features)
            let decisions = CardGenerator.generate(scores: scores, features: features)
            cards = decisions.topSuggestions
            // Hero 数值与趋势页口径一致：
            // - 涨粉/浏览优先用周窗口周期末值序列相邻差（与趋势周线 delta 同源）
            // - 周序列不足 2 条时回退 7 自然日窗口快照首尾差（Dashboard 口径）
            let sortedSnapshots = snapshots.sorted { $0.observedAt < $1.observedAt }
            summary = DecisionSummary(
                followers: followers,
                growth7d: FeatureExtractor.lastPeriodDelta(weekly[.followerGrowth] ?? [])
                    ?? FeatureExtractor.weekCalendarDelta(sortedSnapshots) { $0.followersCount },
                views7d: max(0, FeatureExtractor.lastPeriodDelta(weekly[.profileViews] ?? [])
                    ?? FeatureExtractor.weekCalendarDelta(sortedSnapshots) { $0.totalViews }),
                dataDate: latest?.observedAt
            )
            print("[DecisionsVM] refreshDecisions — top \(cards.count) suggestions")

        } catch {
            errorMessage = error.localizedDescription
            hasData = false; cards = []; summary = nil
        }
    }
}
