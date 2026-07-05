//
//  DecisionsViewModel.swift
//  Follower
//
//  Growth Decision Engine ViewModel — 加载数据、提取特征、评分、生成行动卡片。
//

import Foundation

/// 增长决策页 ViewModel
///
/// 完整数据流水线：
/// 1. 从 Repository 拉取 Snapshot + Metric 原始数据
/// 2. 通过 FeatureExtractor 提取 GrowthFeatures
/// 3. 通过 ScoringEngine 将特征转化为 GrowthScores
/// 4. 通过 CardGenerator 生成 ActionCard 数组供 UI 渲染
///
/// 当无账户或数据加载失败时，自动回退到 Mock 数据，确保 UI 始终可预览。
@Observable
final class DecisionsViewModel {

    // MARK: - Dependencies

    /// Snapshot 数据访问（最新快照 + 趋势查询）
    private let snapshotRepo: SnapshotRepositoryProtocol
    /// Metric 聚合指标数据访问（互动趋势等）
    private let metricRepo: MetricRepositoryProtocol
    /// Account 数据访问（获取已连接账号列表）
    private let accountRepo: AccountRepositoryProtocol

    // MARK: - Published State

    /// 生成的行动卡片列表，UI 直接渲染
    var cards: [ActionCard] = []
    /// 是否正在加载数据（驱动 loading indicator）
    var isLoading: Bool = false
    /// 加载失败时展示的错误信息（nil 表示无错误）
    var errorMessage: String?
    /// 当前选中的账号 ID（nil 表示尚未选择）
    var selectedAccountId: Int64?

    // MARK: - Initialization

    /// 依赖注入初始化
    /// - Parameters:
    ///   - snapshotRepo: Snapshot 数据访问协议实现
    ///   - metricRepo: Metric 聚合指标数据访问协议实现
    ///   - accountRepo: Account 数据访问协议实现
    init(
        snapshotRepo: SnapshotRepositoryProtocol,
        metricRepo: MetricRepositoryProtocol,
        accountRepo: AccountRepositoryProtocol
    ) {
        self.snapshotRepo = snapshotRepo
        self.metricRepo = metricRepo
        self.accountRepo = accountRepo
    }

    // MARK: - Public Methods

    /// 加载首个可用账号并触发决策刷新
    ///
    /// 调用时机：View 的 .task {} 或 .onAppear 中首次调用。
    /// 逻辑：拉取全部账号 → 选择第一个 → 执行 refreshDecisions()。
    func loadInitialAccount() async {
        do {
            let accounts = try await accountRepo.fetchAll()
            if selectedAccountId == nil {
                selectedAccountId = accounts.first?.id
            }
            await refreshDecisions()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 完整流水线：拉取数据 → 提取特征 → 评分 → 生成卡片
    ///
    /// 流水线步骤：
    /// 1. 拉取近 90 天 Snapshot + 最新快照 + 近 90 天 engagementTrend Metric
    /// 2. FeatureExtractor 计算 GrowthFeatures（健康 / 表现 / 时间 / 疲劳）
    /// 3. ScoringEngine 将特征转化为 GrowthScores
    /// 4. CardGenerator 根据分数和特征生成 ActionCard 数组
    ///
    /// 异常处理：
    /// - 无选中账号时直接使用 Mock 数据
    /// - 数据拉取或计算失败时回退到 Mock 数据并设置 errorMessage
    func refreshDecisions() async {
        guard let accountId = selectedAccountId else {
            // 无账户时使用 mock 数据，确保 UI 可预览
            cards = CardGenerator.generate(
                scores: GrowthScores.mock(),
                features: GrowthFeatures.mock
            )
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // 1. 拉取原始数据
            let snapshots = try await snapshotRepo.fetch(
                accountId: accountId,
                from: Date().addingTimeInterval(-90 * 86_400),
                to: Date()
            )
            let latest = try await snapshotRepo.latest(accountId: accountId)
            let followers = latest?.followersCount ?? 0
            let metrics = try await metricRepo.fetch(
                accountId: accountId,
                metricType: .engagementTrend,
                window: .day,
                limit: 90
            )

            // 2. 特征提取
            let health = FeatureExtractor.extractHealth(
                snapshots: snapshots,
                followers: followers
            )
            let contentPerf = FeatureExtractor.extractContentPerformance(
                metrics: metrics
            )
            let timing = FeatureExtractor.extractTimingProfile(
                metrics: metrics
            )
            let fatigue = FeatureExtractor.extractFatigue(
                performance: contentPerf
            )
            let features = GrowthFeatures(
                contentPerformance: contentPerf,
                followerHealth: health,
                timingProfile: timing,
                fatigueIndices: fatigue
            )

            // 3. 评分
            let scores = ScoringEngine.score(features)

            // 4. 生成卡片
            cards = CardGenerator.generate(scores: scores, features: features)

        } catch {
            // 数据拉取失败时回退到 Mock 数据
            errorMessage = error.localizedDescription
            cards = CardGenerator.generate(
                scores: GrowthScores.mock(),
                features: GrowthFeatures.mock
            )
        }
    }
}
