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
    /// 最佳发帖时段（"19:00–21:00"）
    let bestHours: String
    /// 最佳发帖日（1=周日 … 7=周六）
    let bestDay: Int
    /// 最佳时段互动提升倍数
    let timeUplift: Double
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
            let snapshots = try await snapshotRepo.fetch(accountId: accountId,
                from: Date().addingTimeInterval(-90 * 86400), to: Date())
            let latest = try await snapshotRepo.latest(accountId: accountId)
            let followers = latest?.followersCount ?? 0
            let posts = try await mediaPostRepo.fetchRecent(accountId: accountId, limit: 100)

            // 周窗口指标（触达 / 主页浏览 / 平均赞 / 互动率）— 趋势信号与触达类建议
            var weekly: [MetricType: [Metric]] = [:]
            for type in [MetricType.reachEstimate, .profileViews, .averageLikes, .engagementTrend] {
                weekly[type] = (try? await metricRepo.fetch(
                    accountId: accountId, metricType: type, window: .week, limit: 12)) ?? []
            }
            let draftCount = ((try? await draftPostRepo.fetchAll()) ?? []).count

            hasData = !snapshots.isEmpty

            let health = FeatureExtractor.extractHealth(snapshots: snapshots, followers: followers)
            let contentPerf = FeatureExtractor.extractContentPerformance(posts: posts)
            let timing = FeatureExtractor.extractTimingProfile(posts: posts)
            let fatigue = FeatureExtractor.extractFatigue(performance: contentPerf)
            let impact = FeatureExtractor.extractImpact(snapshots: snapshots, posts: posts)
            let context = FeatureExtractor.extractContext(
                snapshots: snapshots, posts: posts, weeklyMetrics: weekly, draftCount: draftCount)
            let features = GrowthFeatures(contentPerformance: contentPerf, followerHealth: health,
                timingProfile: timing, fatigueIndices: fatigue, impact: impact, context: context)

            let scores = ScoringEngine.score(features)
            let decisions = CardGenerator.generate(scores: scores, features: features)
            cards = decisions.topSuggestions
            summary = DecisionSummary(
                followers: followers,
                growth7d: Int(health.followerGrowth7d.rounded()),
                views7d: Int(health.viewsGrowth7d.rounded()),
                bestHours: timing.bestHours,
                bestDay: timing.bestDay,
                timeUplift: impact.hourUplift.uplift,
                dataDate: latest?.observedAt
            )
            print("[DecisionsVM] refreshDecisions — top \(cards.count) suggestions")

        } catch {
            errorMessage = error.localizedDescription
            hasData = false; cards = []; summary = nil
        }
    }
}
