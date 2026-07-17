//
//  PhiServicesTests.swift
//  FollowerTests
//
//  Phi: 三大人群画像 Premium 服务单元测试。
//  covers AuthenticityService / CampaignComparisonService / EngagementHeatmapService。
//

import Testing
import Foundation
@testable import Follower

/// Unit tests for Phi Premium analysis services
struct PhiServicesTests {

    // MARK: - Helpers

    private func makeSnapshot(
        followers: Int, likes: Int = 50, comments: Int = 10,
        shares: Int = 5, views: Int = 500, mediaCount: Int = 5,
        daysAgo: Int = 0
    ) -> Snapshot {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let engagement = Double(likes + comments + shares) / Double(max(views, 1))
        return Snapshot(
            accountId: 1, followersCount: followers, followingCount: 10,
            mediaCount: mediaCount, engagementRate: engagement,
            totalLikes: likes, totalComments: comments,
            totalShares: shares, totalViews: views,
            observedAt: date, createdAt: date
        )
    }

    private func makeEvent(daysAgo: Int, hour: Int = 12) -> Event {
        let cal = Calendar.current
        var date = cal.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        date = cal.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
        return Event(
            accountId: 1, eventType: .profileSnapshot,
            payload: Data(), source: .api,
            observedAt: date, createdAt: date
        )
    }

    // MARK: - AuthenticityService

    /// 健康数据（自然增长 + 正常互动率）→ 高分
    @Test
    func testAuthenticityHealthyAccountScoresHigh() async {
        let service = AuthenticityService()
        let snapshots = (0..<10).map { i in
            makeSnapshot(followers: 1000 + i * 10, likes: 100, comments: 30, views: 2000, daysAgo: 9 - i)
        }
        let result = await service.assess(snapshots: snapshots)
        #expect(result.score > 50, "Healthy account should score above 50")
        #expect(result.engagementQuality > 0)
        #expect(result.followerAuthenticity > 0)
        #expect(!result.hasAnomalies, "Smooth growth should not trigger anomalies")
    }

    /// 稳定小幅波动中插入一个巨大跳跃 → IQR 应检测到异常
    @Test
    func testAuthenticityDetectsAnomalies() async {
        let service = AuthenticityService()
        // 7 天数据：小幅波动基线（+1~+3/天），一天突然暴涨 +500
        let followers = [1000, 1002, 1003, 1503, 1005, 1007, 1010]
        let snapshots = followers.enumerated().map { i, f in
            makeSnapshot(followers: f, daysAgo: 6 - i)
        }
        let result = await service.assess(snapshots: snapshots)
        #expect(result.hasAnomalies, "IQR should detect the +500 spike as anomaly")
        #expect(result.anomalyDescription != nil)
    }

    /// 极低互动率 → 粉丝真实性评分应偏低
    @Test
    func testAuthenticityLowEngagementScoresLow() async {
        let service = AuthenticityService()
        let snapshots = (0..<5).map { i in
            // engagement = 3/500 = 0.6% — 偏低但非零
            makeSnapshot(followers: 1000, likes: 1, comments: 1, shares: 1, views: 500, daysAgo: 4 - i)
        }
        let result = await service.assess(snapshots: snapshots)
        #expect(result.followerAuthenticity < 80, "Low engagement should reduce follower authenticity")
    }

    /// 不足 3 个 snapshot → 返回 insufficient data
    @Test
    func testAuthenticityInsufficientData() async {
        let service = AuthenticityService()
        let snapshots = [makeSnapshot(followers: 100)]
        let result = await service.assess(snapshots: snapshots)
        #expect(result.score == 0)
        #expect(result.growthPattern == "Insufficient data")
    }

    /// 空 snapshot → 不崩溃，返回 0
    @Test
    func testAuthenticityEmptySnapshots() async {
        let service = AuthenticityService()
        let result = await service.assess(snapshots: [])
        #expect(result.score == 0)
        #expect(!result.hasAnomalies)
    }

    /// 自然稳定增长 → growthPattern = "Natural"
    @Test
    func testAuthenticityNaturalGrowth() async {
        let service = AuthenticityService()
        // 每天稳定增长 1-2 个粉丝
        let snapshots = (0..<14).map { i in
            makeSnapshot(followers: 1000 + i + (i % 3), daysAgo: 13 - i)
        }
        let result = await service.assess(snapshots: snapshots)
        #expect(result.growthPattern == "Natural" || result.growthPattern == "Normal",
                 "Slow steady growth should be Natural or Normal, got: \(result.growthPattern)")
    }

    /// 不规律增长（大幅波动）→ growthPattern != Natural
    @Test
    func testAuthenticityIrregularGrowth() async {
        let service = AuthenticityService()
        let snapshots: [Snapshot] = [
            makeSnapshot(followers: 1000, daysAgo: 6),
            makeSnapshot(followers: 1200, daysAgo: 5),
            makeSnapshot(followers: 1050, daysAgo: 4),
            makeSnapshot(followers: 1500, daysAgo: 3),
            makeSnapshot(followers: 1100, daysAgo: 2),
            makeSnapshot(followers: 1300, daysAgo: 1),
            makeSnapshot(followers: 1600, daysAgo: 0),
        ]
        let result = await service.assess(snapshots: snapshots)
        #expect(result.growthPattern != "Natural", "Erratic growth should not be Natural")
        #expect(result.score < 90)
    }

    /// 互动率在健康区间 (1-10%) → 粉丝真实性高分
    @Test
    func testAuthenticityHealthyEngagementRange() async {
        let service = AuthenticityService()
        // engagement ≈ (50+10+5)/500 = 13% — 偏高但正常
        let snapshots = (0..<5).map { i in
            makeSnapshot(followers: 1000, likes: 50, comments: 10, shares: 5, views: 500, daysAgo: 4 - i)
        }
        let result = await service.assess(snapshots: snapshots)
        // 13% > 15% threshold? 65/500 = 13% — within range
        #expect(result.followerAuthenticity >= 60)
    }

    /// 综合评分上限为 100
    @Test
    func testAuthenticityScoreCappedAt100() async {
        let service = AuthenticityService()
        let snapshots = (0..<10).map { i in
            makeSnapshot(followers: 1000 + i, likes: 500, comments: 200, shares: 100, views: 1000, daysAgo: 9 - i)
        }
        let result = await service.assess(snapshots: snapshots)
        #expect(result.score <= 100, "Score must be capped at 100")
        #expect(result.engagementQuality <= 100)
        #expect(result.followerAuthenticity <= 100)
    }

    // MARK: - CampaignComparisonService

    /// 粉丝增长 + 互动率提升 → 正数 delta
    @Test
    func testCampaignPositiveGrowth() async {
        let service = CampaignComparisonService()
        let pre = (0..<5).map { i in
            makeSnapshot(followers: 1000 + i * 5, likes: 50, views: 500, daysAgo: 9 - i)
        }
        let post = (0..<5).map { i in
            makeSnapshot(followers: 1100 + i * 10, likes: 80, views: 700, daysAgo: 4 - i)
        }
        let result = await service.compare(preSnapshots: pre, postSnapshots: post)
        #expect(result.followerDelta > 0, "Post-campaign should have more followers")
        #expect(result.followerGrowthRate > 0)
        #expect(result.engagementDelta != 0)
    }

    /// 粉丝下降 → 负数 delta
    @Test
    func testCampaignNegativeGrowth() async {
        let service = CampaignComparisonService()
        let pre = (0..<5).map { i in
            makeSnapshot(followers: 1000, daysAgo: 9 - i)
        }
        let post = (0..<5).map { i in
            makeSnapshot(followers: 900, daysAgo: 4 - i)
        }
        let result = await service.compare(preSnapshots: pre, postSnapshots: post)
        #expect(result.followerDelta < 0)
        #expect(result.followerGrowthRate < 0)
    }

    /// 空 pre snapshot → 不崩溃，返回 0
    @Test
    func testCampaignEmptyPreSnapshots() async {
        let service = CampaignComparisonService()
        let post = [makeSnapshot(followers: 100)]
        let result = await service.compare(preSnapshots: [], postSnapshots: post)
        #expect(result.preFollowers == 0)
        #expect(result.postFollowers == 100)
        #expect(result.followerGrowthRate == 0, "preFollowers=0 should yield 0% growth rate to avoid division by zero")
    }

    /// 空 post snapshot → 不崩溃
    @Test
    func testCampaignEmptyPostSnapshots() async {
        let service = CampaignComparisonService()
        let pre = [makeSnapshot(followers: 100)]
        let result = await service.compare(preSnapshots: pre, postSnapshots: [])
        #expect(result.preFollowers == 100)
        #expect(result.postFollowers == 0)
    }

    /// 单 snapshot 对比 → followers 直接为 snapshot 的值
    @Test
    func testCampaignSingleSnapshot() async {
        let service = CampaignComparisonService()
        let pre = [makeSnapshot(followers: 500, likes: 25, views: 300)]
        let post = [makeSnapshot(followers: 600, likes: 40, views: 400)]
        let result = await service.compare(preSnapshots: pre, postSnapshots: post)
        #expect(result.preFollowers == 500)
        #expect(result.postFollowers == 600)
        #expect(result.followerDelta == 100)
    }

    /// 多 snapshot → 取均值对比
    @Test
    func testCampaignAveragesMultipleSnapshots() async {
        let service = CampaignComparisonService()
        let pre = [
            makeSnapshot(followers: 100, views: 1000, daysAgo: 3),
            makeSnapshot(followers: 200, views: 1000, daysAgo: 2),
        ]
        let post = [
            makeSnapshot(followers: 300, views: 1000, daysAgo: 1),
            makeSnapshot(followers: 400, views: 1000, daysAgo: 0),
        ]
        let result = await service.compare(preSnapshots: pre, postSnapshots: post)
        #expect(result.preFollowers == 150)   // (100+200)/2
        #expect(result.postFollowers == 350)  // (300+400)/2
        #expect(result.followerDelta == 200)
    }

    // MARK: - EngagementHeatmapService

    /// 多个 Event 分布在不同 (weekday, hour) → 生成 7×24=168 个 cell
    @Test
    func testHeatmapGeneratesFullGrid() async {
        let service = EngagementHeatmapService()
        let events = (0..<7).flatMap { day in
            (0..<24).map { hour in
                makeEvent(daysAgo: day, hour: hour)
            }
        }
        let result = await service.generate(from: events)
        #expect(result.cells.count == 168, "Should generate exactly 7 × 24 = 168 cells")
    }

    /// 集中在某一天的 Event → 该天密度最高
    @Test
    func testHeatmapFindsPeakDay() async {
        let service = EngagementHeatmapService()
        // 大量 event 放在周三 (weekday=4) 的 19:00
        var events: [Event] = []
        for _ in 0..<50 {
            events.append(makeEvent(daysAgo: 2, hour: 19))  // 2 days ago = depends on today
        }
        // 少量 event 在其他时间
        events.append(makeEvent(daysAgo: 1, hour: 10))
        events.append(makeEvent(daysAgo: 3, hour: 8))

        let result = await service.generate(from: events)
        #expect(!result.peakDescription.isEmpty)
        #expect(result.bestHour == 19, "Peak hour should be 19")
        let peakDensity = result.density(weekday: result.bestDay, hour: result.bestHour)
        #expect(peakDensity == 1.0, "Peak density should be 1.0 (normalized)")
    }

    /// 空 Event 数组 → 返回空结果
    @Test
    func testHeatmapEmptyEvents() async {
        let service = EngagementHeatmapService()
        let result = await service.generate(from: [])
        #expect(result.cells.isEmpty)
        #expect(result.peakDescription == "No data")
        #expect(result.bestDay == 0)
    }

    /// 单 Event → 密度为 1.0，最佳时间即该 Event 时间
    @Test
    func testHeatmapSingleEvent() async {
        let service = EngagementHeatmapService()
        let event = makeEvent(daysAgo: 0, hour: 15)
        let result = await service.generate(from: [event])
        #expect(result.cells.count == 168)
        #expect(result.bestHour == 15)
        let density = result.density(weekday: result.bestDay, hour: 15)
        #expect(density == 1.0)
    }

    /// density 查询不存在 (weekday, hour) 应返回 0
    @Test
    func testHeatmapDensityMissingCellReturnsZero() async {
        let service = EngagementHeatmapService()
        let result = await service.generate(from: [])
        let d = result.density(weekday: 1, hour: 0)
        #expect(d == 0)
    }

    /// 均匀分布 → 所有密度 <= 1.0
    @Test
    func testHeatmapUniformDistribution() async {
        let service = EngagementHeatmapService()
        let events = (0..<7).map { day in makeEvent(daysAgo: day, hour: 12) }
        let result = await service.generate(from: events)
        for cell in result.cells {
            #expect(cell.density >= 0 && cell.density <= 1.0,
                     "Density must be in [0, 1], got \(cell.density)")
        }
    }

    // MARK: - DashboardViewModel Phi Integration

    /// DashboardViewModel 初始化后 Phi 属性应为 nil
    @MainActor
    @Test
    func testDashboardVMPhiPropertiesInitialNil() {
        let db = DatabaseManager.shared
        let snapshotRepo = SnapshotRepository(db: db)
        let metricRepo = MetricRepository(db: db)
        let accountRepo = AccountRepository(db: db)
        let eventRepo = EventRepository(db: db)

        let vm = DashboardViewModel(
            snapshotRepo: snapshotRepo,
            metricRepo: metricRepo,
            accountRepo: accountRepo,
            syncEngine: MockSyncEngine(),
            eventRepo: eventRepo,
            predictionService: PredictionService(),
            activityService: ActivityAnalysisService(),
            retentionService: RetentionAnalysisService(),
            scoringService: ScoringService(),
            geoService: GeoDistributionService(),
            comparisonService: ComparisonService(),
            aiService: AIAnalysisService(),
            authenticityService: AuthenticityService(),
            campaignComparisonService: CampaignComparisonService(),
            engagementHeatmapService: EngagementHeatmapService()
        )
        #expect(vm.authenticityResult == nil)
        #expect(vm.campaignResult == nil)
        #expect(vm.heatmapResult == nil)
    }

    /// loadPremiumInsights 填充数据后 Phi 属性应被填充
    @MainActor
    @Test
    func testDashboardVMLoadPremiumInsightsPopulatesPhiProperties() async {
        // 准备 10 天递增粉丝的 snapshot + events
        let snapshots = (0..<10).map { i in
            makeSnapshot(followers: 1000 + i * 10, likes: 50 + i * 2, comments: 10 + i, views: 500, daysAgo: 9 - i)
        }
        let events = (0..<10).map { i in makeEvent(daysAgo: i, hour: 12) }

        let mockSnapshotRepo = MockSnapshotRepository()
        mockSnapshotRepo.snapshots = snapshots
        mockSnapshotRepo.latestSnapshot = snapshots.last

        let mockEventRepo = MockEventRepository()
        mockEventRepo.events = events

        let mockAccountRepo = MockAccountRepository()
        let account = Account(
            id: 1, platform: .instagram, username: "test", displayName: "T",
            authState: .authorized, createdAt: Date(), updatedAt: Date()
        )
        mockAccountRepo.accounts = [account]

        let vm = DashboardViewModel(
            snapshotRepo: mockSnapshotRepo,
            metricRepo: MockMetricRepository(),
            accountRepo: mockAccountRepo,
            syncEngine: MockSyncEngine(),
            eventRepo: mockEventRepo,
            predictionService: PredictionService(),
            activityService: ActivityAnalysisService(),
            retentionService: RetentionAnalysisService(),
            scoringService: ScoringService(),
            geoService: GeoDistributionService(),
            comparisonService: ComparisonService(),
            aiService: AIAnalysisService(),
            authenticityService: AuthenticityService(),
            campaignComparisonService: CampaignComparisonService(),
            engagementHeatmapService: EngagementHeatmapService()
        )
        vm.selectedAccountId = 1
        await vm.loadAllData()

        // Phi 属性应被填充
        #expect(vm.authenticityResult != nil, "authenticityResult should be populated")
        #expect(vm.campaignResult != nil, "campaignResult should be populated")
        #expect(vm.heatmapResult != nil, "heatmapResult should be populated")

        if let auth = vm.authenticityResult {
            #expect(auth.score >= 0 && auth.score <= 100)
            #expect(!auth.growthPattern.isEmpty)
        }
        if let campaign = vm.campaignResult {
            #expect(campaign.preFollowers > 0)
            #expect(campaign.postFollowers > 0)
        }
        if let heatmap = vm.heatmapResult {
            #expect(!heatmap.cells.isEmpty)
            #expect(!heatmap.peakDescription.isEmpty)
        }
    }
}
// Mock classes reused from PremiumViewModelTests.swift (same module)
