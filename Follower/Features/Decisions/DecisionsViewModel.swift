//
//  DecisionsViewModel.swift
//  Follower
//
//  Growth Decision Engine ViewModel — 加载数据、提取特征、评分、生成行动卡片。
//  与 Dashboard 同步：无账号 → 空状态；有账号无数据 → 等待同步；有数据 → 生成卡片。
//

import Foundation

/// 增长决策页 ViewModel
///
/// 完整数据流水线：
/// 1. 从 Repository 拉取 Snapshot + Metric 原始数据
/// 2. 通过 FeatureExtractor 提取 GrowthFeatures
/// 3. 通过 ScoringEngine 将特征转化为 GrowthScores
/// 4. 通过 CardGenerator 生成 ActionCard 数组
///
/// 无账号 → cards 为空 → View 展示 EmptyState
/// 有账号无数据 → 生成 Insight 卡片 + 提示同步
/// 有数据 → 全量 4 类卡片（Primary / Alert / Recovery / Insight）
@Observable
final class DecisionsViewModel {

    // MARK: - Dependencies

    private let snapshotRepo: SnapshotRepositoryProtocol
    private let metricRepo: MetricRepositoryProtocol
    private let accountRepo: AccountRepositoryProtocol

    // MARK: - Published State

    /// 生成的行动卡片列表
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

    // MARK: - Initialization

    init(snapshotRepo: SnapshotRepositoryProtocol,
         metricRepo: MetricRepositoryProtocol,
         accountRepo: AccountRepositoryProtocol) {
        self.snapshotRepo = snapshotRepo
        self.metricRepo = metricRepo
        self.accountRepo = accountRepo
    }

    // MARK: - Public Methods

    /// 页面首次加载 — 仅获取账号列表，不拉取数据（等 Dashboard sync 后用户手动刷新）
    func loadInitialAccount() async {
        do {
            accounts = try await accountRepo.fetchAll()
            if selectedAccountId == nil { selectedAccountId = accounts.first?.id }
        } catch { errorMessage = error.localizedDescription }
    }

    /// 完整流水线：拉取数据 → 提取特征 → 评分 → 生成卡片
    func refreshDecisions() async {
        guard let accountId = selectedAccountId else {
            hasData = false; cards = []
            return
        }
        isLoading = true; defer { isLoading = false }
        do {
            let snapshots = try await snapshotRepo.fetch(accountId: accountId,
                from: Date().addingTimeInterval(-90 * 86400), to: Date())
            let latest = try await snapshotRepo.latest(accountId: accountId)
            let followers = latest?.followersCount ?? 0
            let metrics = try await metricRepo.fetch(accountId: accountId,
                metricType: .engagementTrend, window: .day, limit: 90)

            hasData = !snapshots.isEmpty

            let health = FeatureExtractor.extractHealth(snapshots: snapshots, followers: followers)
            let contentPerf = FeatureExtractor.extractContentPerformance(metrics: metrics)
            let timing = FeatureExtractor.extractTimingProfile(metrics: metrics)
            let fatigue = FeatureExtractor.extractFatigue(performance: contentPerf)
            let features = GrowthFeatures(contentPerformance: contentPerf, followerHealth: health,
                timingProfile: timing, fatigueIndices: fatigue)

            let scores = ScoringEngine.score(features)
            cards = CardGenerator.generate(scores: scores, features: features)

        } catch {
            errorMessage = error.localizedDescription
            hasData = false; cards = []
        }
    }
}
