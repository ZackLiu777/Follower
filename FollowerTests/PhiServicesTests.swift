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

    private func makeEvent(daysAgo: Int, hour: Int = 12, type: EventType = .postInteraction) -> Event {
        let cal = Calendar.current
        var date = cal.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        date = cal.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
        return Event(
            accountId: 1, eventType: type,
            payload: Data(), source: .api,
            observedAt: date, createdAt: date
        )
    }

    /// 固定日期构造 Event（与运行日期无关，weekday 确定）：
    /// 2020-01-06 = 周一，2020-01-07 = 周二，2020-01-08 = 周三
    private func makeEvent(on year: Int, month: Int, day: Int, hour: Int, type: EventType = .postInteraction) -> Event {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day; comps.hour = hour
        let date = Calendar.current.date(from: comps) ?? Date()
        return Event(
            accountId: 1, eventType: type,
            payload: Data(), source: .api,
            observedAt: date, createdAt: date
        )
    }

    /// 固定日期构造 Snapshot（与运行日期无关，weekday 确定）：
    /// 2020-01-06 = 周一，2020-01-07 = 周二，2020-01-08 = 周三
    private func makeSnapshot(on year: Int, month: Int, day: Int, hour: Int,
                              likes: Int = 0, comments: Int = 0, shares: Int = 0) -> Snapshot {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day; comps.hour = hour
        let date = Calendar.current.date(from: comps) ?? Date()
        return Snapshot(
            accountId: 1, followersCount: 1000, followingCount: 10,
            mediaCount: 5, engagementRate: 0,
            totalLikes: likes, totalComments: comments,
            totalShares: shares, totalViews: 500,
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
        let result = await service.generate(from: events, snapshots: [])
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

        let result = await service.generate(from: events, snapshots: [])
        #expect(!result.peakDescription.isEmpty)
        #expect(result.bestHour == 19, "Peak hour should be 19")
        let peakDensity = result.density(weekday: result.bestDay, hour: result.bestHour)
        #expect(peakDensity == 1.0, "Peak density should be 1.0 (normalized)")
    }

    /// 空 Event 数组 → 返回空结果
    @Test
    func testHeatmapEmptyEvents() async {
        let service = EngagementHeatmapService()
        let result = await service.generate(from: [], snapshots: [])
        #expect(result.cells.isEmpty)
        #expect(result.peakDescription == "No data")
        #expect(result.bestDay == 0)
    }

    /// 单 Event → 密度为 1.0，最佳时间即该 Event 时间
    @Test
    func testHeatmapSingleEvent() async {
        let service = EngagementHeatmapService()
        let event = makeEvent(daysAgo: 0, hour: 15)
        let result = await service.generate(from: [event], snapshots: [])
        #expect(result.cells.count == 168)
        #expect(result.bestHour == 15)
        let density = result.density(weekday: result.bestDay, hour: 15)
        #expect(density == 1.0)
    }

    /// density 查询不存在 (weekday, hour) 应返回 0
    @Test
    func testHeatmapDensityMissingCellReturnsZero() async {
        let service = EngagementHeatmapService()
        let result = await service.generate(from: [], snapshots: [])
        let d = result.density(weekday: 1, hour: 0)
        #expect(d == 0)
    }

    /// 均匀分布 → 所有密度 <= 1.0
    @Test
    func testHeatmapUniformDistribution() async {
        let service = EngagementHeatmapService()
        let events = (0..<7).map { day in makeEvent(daysAgo: day, hour: 12) }
        let result = await service.generate(from: events, snapshots: [])
        for cell in result.cells {
            #expect(cell.density >= 0 && cell.density <= 1.0,
                     "Density must be in [0, 1], got \(cell.density)")
        }
    }

    /// 分布字段：totalEvents 与星期分布（3 个周一 + 1 个周二 → 周一为峰值日）
    @Test
    func testHeatmapDayDistribution() async {
        let service = EngagementHeatmapService()
        let events = [
            makeEvent(on: 2020, month: 1, day: 6, hour: 9),   // Mon
            makeEvent(on: 2020, month: 1, day: 6, hour: 10),  // Mon
            makeEvent(on: 2020, month: 1, day: 6, hour: 11),  // Mon
            makeEvent(on: 2020, month: 1, day: 7, hour: 9),   // Tue
        ]
        let result = await service.generate(from: events, snapshots: [])
        #expect(result.totalEvents == 4)
        #expect(result.dayDistribution.count == 7)
        #expect(result.dayDistribution[1] == 1.0, "Monday (index 1) should be the peak day")
        #expect(abs(result.dayDistribution[2] - 1.0 / 3.0) < 0.001, "Tuesday should be 1/3 of Monday")
        #expect(result.dayDistribution[0] == 0, "Sunday should be 0")
    }

    /// 时段分布：上午(6-11) 与 晚上(18-23) 有事件 → 上午为峰值时段
    @Test
    func testHeatmapPeriodDistribution() async {
        let service = EngagementHeatmapService()
        let events = [
            makeEvent(on: 2020, month: 1, day: 6, hour: 8),   // 上午
            makeEvent(on: 2020, month: 1, day: 7, hour: 9),   // 上午
            makeEvent(on: 2020, month: 1, day: 8, hour: 22),  // 晚上
        ]
        let result = await service.generate(from: events, snapshots: [])
        #expect(result.totalEvents == 3)
        #expect(result.periodDistribution.count == 4)
        #expect(result.periodDistribution[1] == 1.0, "Morning (index 1) should be the peak period")
        #expect(result.periodDistribution[3] > 0 && result.periodDistribution[3] < 1)
        #expect(result.periodDistribution[0] == 0, "Late night should be 0")
        #expect(result.periodDistribution[2] == 0, "Afternoon should be 0")
    }

    /// 空结果：分布数组全零
    @Test
    func testHeatmapEmptyDistribution() async {
        let service = EngagementHeatmapService()
        let result = await service.generate(from: [], snapshots: [])
        #expect(result.totalEvents == 0)
        #expect(result.dayDistribution.allSatisfy { $0 == 0 })
        #expect(result.periodDistribution.allSatisfy { $0 == 0 })
    }

    /// 事件权重（v0.16 双通道）：真互动 1.0 / followerChange 0.3 / profileSnapshot 0
    @Test
    func testHeatmapEventWeights() {
        #expect(EngagementHeatmapService.eventWeight(for: .postInteraction) == 1.0)
        #expect(EngagementHeatmapService.eventWeight(for: .storyView) == 1.0)
        #expect(EngagementHeatmapService.eventWeight(for: .engagementUpdate) == 1.0)
        #expect(EngagementHeatmapService.eventWeight(for: .followerChange) == 0.3)
        #expect(EngagementHeatmapService.eventWeight(for: .profileSnapshot) == 0,
                 "profileSnapshot is covered by the snapshot-delta channel")
    }

    /// 快照互动增量通道：likes 环比增长归入第二快照所在 (weekday, hour)，按最大增量归一化
    @Test
    func testHeatmapSnapshotDeltaChannel() async {
        let service = EngagementHeatmapService()
        let snapshots = [
            makeSnapshot(on: 2020, month: 1, day: 6, hour: 9, likes: 100),   // Mon 09:00（首点无增量）
            makeSnapshot(on: 2020, month: 1, day: 7, hour: 10, likes: 400),  // Tue 10:00 → Δ300
            makeSnapshot(on: 2020, month: 1, day: 8, hour: 11, likes: 550),  // Wed 11:00 → Δ150
        ]
        let result = await service.generate(from: [], snapshots: snapshots)

        let cal = Calendar.current
        let tue = cal.date(from: DateComponents(year: 2020, month: 1, day: 7, hour: 10))!
        let wed = cal.date(from: DateComponents(year: 2020, month: 1, day: 8, hour: 11))!
        #expect(result.density(weekday: cal.component(.weekday, from: tue),
                               hour: cal.component(.hour, from: tue)) == 1.0,
                 "Δ300 is the max delta → density 1.0")
        #expect(result.density(weekday: cal.component(.weekday, from: wed),
                               hour: cal.component(.hour, from: wed)) == 0.5,
                 "Δ150 normalized to 0.5")
        #expect(result.totalEvents == 0, "No events passed")
    }

    /// 只有快照、没有事件 → 快照通道单独也能生成 7×24 网格
    @Test
    func testHeatmapSnapshotOnly() async {
        let service = EngagementHeatmapService()
        let snapshots = [makeSnapshot(on: 2020, month: 1, day: 6, hour: 9, likes: 100)]
        let result = await service.generate(from: [], snapshots: snapshots)
        #expect(result.cells.count == 168)
    }

    /// followerChange 弱信号参与事件通道（0.3 权重）
    @Test
    func testHeatmapFollowerChangeWeighted() async {
        let service = EngagementHeatmapService()
        // 5 个 followerChange 事件 → 权重合计 1.5
        let events = (0..<5).map { i in
            makeEvent(on: 2020, month: 1, day: 6, hour: 9, type: .followerChange)
        }
        let result = await service.generate(from: events, snapshots: [])
        let cal = Calendar.current
        let mon = cal.date(from: DateComponents(year: 2020, month: 1, day: 6, hour: 9))!
        let wd = cal.component(.weekday, from: mon)
        #expect(result.density(weekday: wd, hour: 9) == 1.0, "Only cell → density 1.0")
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
            engagementHeatmapService: EngagementHeatmapService(),
            mediaPostRepository: MediaPostRepository(db: DatabaseManager.shared),
            bestPostingTimeService: BestPostingTimeService(),
            contentProfileService: ContentProfileService(),
            engagementFunnelService: EngagementFunnelService(),
            contentAttributionService: ContentAttributionService(),
            milestoneService: MilestoneService(),
            apiClient: MockInstagramAPIClient(),
            tokenProvider: MockTokenProvider(),
            mediaKitService: MediaKitService()
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
            engagementHeatmapService: EngagementHeatmapService(),
            mediaPostRepository: MediaPostRepository(db: DatabaseManager.shared),
            bestPostingTimeService: BestPostingTimeService(),
            contentProfileService: ContentProfileService(),
            engagementFunnelService: EngagementFunnelService(),
            contentAttributionService: ContentAttributionService(),
            milestoneService: MilestoneService(),
            apiClient: MockInstagramAPIClient(),
            tokenProvider: MockTokenProvider(),
            mediaKitService: MediaKitService()
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

// MARK: - ContentProfileServiceTests

struct ContentProfileServiceTests {

    private func makePost(id: Int, type: MediaPostType, likes: Int, comments: Int = 0,
                          hour: Int = 12, weekday: Int = 2, caption: String = "c") -> MediaPost {
        let cal = Calendar.current
        let date = cal.date(from: DateComponents(year: 2026, month: 1, day: 5 + (weekday - 2), hour: hour))!
        return MediaPost(id: Int64(id), accountId: 1, igMediaID: "\(id)",
            type: type, date: date, likes: likes, comments: comments,
            caption: caption, mediaURL: nil, permalink: nil)
    }

    /// 档位判定：爆款 ≥ 2×平均，低互动 ≤ 0.3×平均
    @Test
    func testTierClassification() async {
        let service = ContentProfileService()
        // 平均 = (1000 + 100 + 100 + 10)/4 = 302.5；爆款阈值 605，低互动阈值 90.75
        let posts = [
            makePost(id: 1, type: .video, likes: 1000),
            makePost(id: 2, type: .image, likes: 100),
            makePost(id: 3, type: .image, likes: 100),
            makePost(id: 4, type: .image, likes: 10),
        ]
        let result = await service.analyze(from: posts)
        #expect(result.viralCount == 1)
        #expect(result.averageCount == 2)
        #expect(result.lowCount == 1)
    }

    /// 爆款公式：≥2 爆款时给出 dominant 类型/星期/小时
    @Test
    func testViralFormula() async {
        let service = ContentProfileService()
        // 平均 = (1000+900+10+10)/4 = 480；爆款 = 1000/900
        let posts = [
            makePost(id: 1, type: .video, likes: 1000, hour: 19, weekday: 4),
            makePost(id: 2, type: .video, likes: 900, hour: 19, weekday: 4),
            makePost(id: 3, type: .image, likes: 10, hour: 8),
            makePost(id: 4, type: .image, likes: 10, hour: 9),
        ]
        let result = await service.analyze(from: posts)
        #expect(result.viralFormula != nil)
        #expect(result.viralFormula?.dominantType == .reel)
        #expect(result.viralFormula?.dominantHour == 19)
        #expect(result.viralFormula?.dominantWeekday == 4)
    }

    /// 爆款 < 2 → 无公式；Top 榜按互动降序
    @Test
    func testNoFormulaAndTopPosts() async {
        let service = ContentProfileService()
        let posts = [
            makePost(id: 1, type: .image, likes: 30),
            makePost(id: 2, type: .video, likes: 60),
            makePost(id: 3, type: .image, likes: 5),
        ]
        let result = await service.analyze(from: posts)
        #expect(result.viralFormula == nil)
        #expect(result.topPosts.count == 3)
        #expect(result.topPosts[0].engagement == 60)
        #expect(result.topPosts[0].type == .reel)
    }

    /// 空输入 → 空结果
    @Test
    func testEmptyPosts() async {
        let result = await ContentProfileService().analyze(from: [])
        #expect(result.totalPosts == 0)
        #expect(result.topPosts.isEmpty)
        #expect(result.typeBands.isEmpty)
    }
}

// MARK: - EngagementFunnelServiceTests

struct EngagementFunnelServiceTests {

    private func makeSnapshot(day: Int, followers: Int, likes: Int, comments: Int, views: Int) -> Snapshot {
        Snapshot(id: nil, accountId: 1,
            followersCount: followers, followingCount: 100, mediaCount: 10,
            engagementRate: 0.05, totalLikes: likes, totalComments: comments,
            totalShares: 1, totalViews: views,
            observedAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(day) * 86_400),
            createdAt: Date())
    }

    /// 已知增量 → 三环节转化率精确可算
    @Test
    func testFunnelRates() async {
        let service = EngagementFunnelService()
        // ΔF=100, Δ互动=1000（likes 800 + comments 200）, Δviews=10000
        let snaps = [
            makeSnapshot(day: 0, followers: 10_000, likes: 800, comments: 200, views: 10_000),
            makeSnapshot(day: 1, followers: 10_100, likes: 1_600, comments: 400, views: 20_000),
        ]
        let result = await service.analyze(snapshots: snaps)
        #expect(abs(result.viewToEngagement - 0.10) < 1e-9)   // 1000/10000
        #expect(abs(result.engagementToFollower - 0.10) < 1e-9) // 100/1000
        #expect(abs(result.viewToFollower - 0.01) < 1e-9)     // 100/10000
    }

    /// 瓶颈检测：互动环节最弱 → .engagement + 量化机会
    @Test
    func testBottleneckAndOpportunity() async {
        let service = EngagementFunnelService()
        // 互动转化低：Δviews=10000, Δ互动=100, ΔF=50
        let snaps = [
            makeSnapshot(day: 0, followers: 10_000, likes: 500, comments: 100, views: 10_000),
            makeSnapshot(day: 1, followers: 10_050, likes: 550, comments: 150, views: 20_000),
        ]
        let result = await service.analyze(snapshots: snaps)
        // viewToEng = 100/10000 = 0.01；engToFollower = 50/100 = 0.5
        #expect(result.bottleneck == .engagement)
        // 机会 = Δeng × 0.1 × engToFollower = 100 × 0.1 × 0.5 = 5
        #expect(result.opportunityFollowers == 5)
    }

    /// 空快照 → 空结果
    @Test
    func testEmptySnapshots() async {
        let result = await EngagementFunnelService().analyze(snapshots: [])
        #expect(result.bottleneck == .none)
        #expect(result.opportunityFollowers == 0)
    }
}

// MARK: - ContentAttributionServiceTests

struct ContentAttributionServiceTests {

    private func makePost(id: Int, type: MediaPostType, likes: Int, comments: Int = 0, day: Int) -> MediaPost {
        let cal = Calendar.current
        let date = cal.date(byAdding: .day, value: day, to: cal.startOfDay(for: Date()))!
        return MediaPost(id: Int64(id), accountId: 1, igMediaID: "attr-\(id)",
            type: type, date: date, likes: likes, comments: comments,
            caption: "p\(id)", mediaURL: nil, permalink: nil)
    }

    private func makeSnapshot(day: Int, followers: Int) -> Snapshot {
        let cal = Calendar.current
        let date = cal.date(byAdding: .day, value: day, to: cal.startOfDay(for: Date()))!
        return Snapshot(id: nil, accountId: 1, followersCount: followers,
            followingCount: 100, mediaCount: 10, engagementRate: 0.05,
            totalLikes: 500, totalComments: 50, totalShares: 10, totalViews: 1000,
            observedAt: date, createdAt: Date())
    }

    /// 冷启动：帖子 < 5 → nil
    @Test
    func testColdStart() async {
        let service = ContentAttributionService()
        let posts = (0..<4).map { makePost(id: $0, type: .image, likes: 10, day: $0) }
        let snaps = [makeSnapshot(day: -1, followers: 100), makeSnapshot(day: 10, followers: 200)]
        #expect(await service.analyze(posts: posts, snapshots: snaps) == nil)
    }

    /// 单帖窗口归因：7 天窗口涨粉全部归给该帖
    @Test
    func testSinglePostWindow() async {
        let service = ContentAttributionService()
        let posts = (0..<5).map { makePost(id: $0, type: .image, likes: 10, day: $0 * 10) }  // 间隔 10 天，窗口不重叠
        // day 0 发帖：窗口 [0,6]，快照 day -1=1000 → day 7=1050 → +50
        let snaps = [
            makeSnapshot(day: -1, followers: 1000),
            makeSnapshot(day: 7, followers: 1050),
        ]
        let result = try? #require(await service.analyze(posts: posts, snapshots: snaps))
        #expect(result != nil)
        #expect(abs((result?.totalAttributedGain ?? 0) - 50) < 0.01, "窗口涨粉 50 全归因")
        #expect(result?.typeContribution.first?.type == .photo)
    }

    /// 重叠窗口按互动占比分摊：同窗口两帖，互动高者分得多
    @Test
    func testSharedWindowSplitByEngagement() async {
        let service = ContentAttributionService()
        // 两帖同一天发（day 0）：互动 90 vs 10 → 窗口涨粉 100 按 9:1 分摊
        let posts = [
            makePost(id: 0, type: .video, likes: 90, day: 0),
            makePost(id: 1, type: .image, likes: 10, day: 0),
            makePost(id: 2, type: .image, likes: 10, day: 30),
            makePost(id: 3, type: .image, likes: 10, day: 40),
            makePost(id: 4, type: .image, likes: 10, day: 50),
        ]
        let snaps = [
            makeSnapshot(day: -1, followers: 1000),
            makeSnapshot(day: 7, followers: 1100),   // day0 窗口 +100
        ]
        let result = try? #require(await service.analyze(posts: posts, snapshots: snaps))
        let total = result?.totalAttributedGain ?? 0
        #expect(abs(total - 100) < 0.01)
        // video 90% → 90，image 10% → 10（同窗口分摊）
        let video = result?.typeContribution.first { $0.type == .reel }?.contribution.followerGain ?? 0
        let photo = result?.typeContribution.first { $0.type == .photo }?.contribution.followerGain ?? 0
        #expect(abs(video - 90) < 0.01, "Reel 分得 90%（90/100 互动）")
        #expect(abs(photo - 10) < 0.01, "Photo 分得 10%")
    }

    /// 负增长窗口不计入归因
    @Test
    func testNegativeWindowIgnored() async {
        let service = ContentAttributionService()
        let posts = (0..<5).map { makePost(id: $0, type: .image, likes: 10, day: $0 * 10) }
        // day0 窗口下降 → 不计
        let snaps = [
            makeSnapshot(day: -1, followers: 1000),
            makeSnapshot(day: 7, followers: 900),    // -100 → 忽略
        ]
        let result = try? #require(await service.analyze(posts: posts, snapshots: snaps))
        #expect(result != nil)
        #expect(abs(result?.totalAttributedGain ?? 999) < 0.01, "负增长不归因")
    }

    /// 快照不足 → nil
    @Test
    func testInsufficientSnapshots() async {
        let service = ContentAttributionService()
        let posts = (0..<5).map { makePost(id: $0, type: .image, likes: 10, day: $0) }
        #expect(await service.analyze(posts: posts, snapshots: [makeSnapshot(day: 0, followers: 100)]) == nil)
    }
}

// MARK: - ReelsAnalysisServiceTests

struct ReelsAnalysisServiceTests {

    /// mapReel：完播率 = avg_watch_time / duration；Saves/Shares 率正确
    @Test
    func testMapReel() {
        let media = IGMedia(id: "m1", caption: "reel", mediaType: "VIDEO", permalink: nil,
            timestamp: nil, likeCount: nil, commentsCount: nil, mediaURL: nil, thumbnailURL: nil,
            mediaDuration: 30)
        let insights: [IGInsightValue] = [
            .scalar("plays", 10000),
            .scalar("saved", 400),
            .scalar("shares", 200),
            .scalar("avg_watch_time", 18),
        ]
        let reel = ReelsAnalysisService.mapReel(media: media, insights: insights)
        #expect(reel != nil)
        #expect(abs((reel?.completionRate ?? 0) - 0.6) < 1e-9, "18/30 = 0.6")
        #expect(abs((reel?.saveRate ?? 0) - 0.04) < 1e-9)
        #expect(abs((reel?.shareRate ?? 0) - 0.02) < 1e-9)
    }

    /// 非视频 / 无时长 / 无 plays → nil
    @Test
    func testMapReelInvalid() {
        let image = IGMedia(id: "m2", caption: nil, mediaType: "IMAGE", permalink: nil,
            timestamp: nil, likeCount: nil, commentsCount: nil, mediaURL: nil, thumbnailURL: nil,
            mediaDuration: nil)
        #expect(ReelsAnalysisService.mapReel(media: image, insights: []) == nil)

        let videoNoDuration = IGMedia(id: "m3", caption: nil, mediaType: "VIDEO", permalink: nil,
            timestamp: nil, likeCount: nil, commentsCount: nil, mediaURL: nil, thumbnailURL: nil,
            mediaDuration: nil)
        #expect(ReelsAnalysisService.mapReel(media: videoNoDuration, insights: []) == nil)

        let videoNoPlays = IGMedia(id: "m4", caption: nil, mediaType: "VIDEO", permalink: nil,
            timestamp: nil, likeCount: nil, commentsCount: nil, mediaURL: nil, thumbnailURL: nil,
            mediaDuration: 20)
        #expect(ReelsAnalysisService.mapReel(media: videoNoPlays, insights: [.scalar("saved", 5)]) == nil)
    }

    /// 完播率 clamp：avg_watch > duration → 1.0；负值 → 0
    @Test
    func testCompletionClamped() {
        let media = IGMedia(id: "m5", caption: nil, mediaType: "VIDEO", permalink: nil,
            timestamp: nil, likeCount: nil, commentsCount: nil, mediaURL: nil, thumbnailURL: nil,
            mediaDuration: 10)
        let over = ReelsAnalysisService.mapReel(media: media,
            insights: [.scalar("plays", 1), .scalar("avg_watch_time", 99)])
        #expect(over?.completionRate == 1.0)
    }

    /// aggregate：平均完播率 / Saves 率 / 最佳 Reel（按完播率降序）
    @Test
    func testAggregate() {
        let a = ReelPerformance(mediaID: "a", caption: "", duration: 30, plays: 1000,
            completionRate: 0.4, saves: 100, shares: 50, saveRate: 0.1, shareRate: 0.05)
        let b = ReelPerformance(mediaID: "b", caption: "", duration: 30, plays: 1000,
            completionRate: 0.8, saves: 100, shares: 50, saveRate: 0.1, shareRate: 0.05)
        let result = ReelsAnalysisService.aggregate([a, b])
        #expect(result != nil)
        #expect(abs((result?.avgCompletionRate ?? 0) - 0.6) < 1e-9)
        #expect(result?.bestReel?.mediaID == "b")
        #expect(result?.reels.first?.mediaID == "b", "按完播率降序")
    }

    /// 空数组 → nil
    @Test
    func testAggregateEmpty() {
        #expect(ReelsAnalysisService.aggregate([]) == nil)
    }

    /// 百分比格式化
    @Test
    func testPercentFormat() {
        #expect(ReelsAnalysisService.percent(0.42) == "42%")
        #expect(ReelsAnalysisService.percent(1.0) == "100%")
        #expect(ReelsAnalysisService.percent(0) == "0%")
    }
}

// MARK: - IGInsightValue 测试辅助

extension IGInsightValue {
    /// 构造标量指标（breakdown 形式）
    static func scalar(_ name: String, _ value: Double) -> IGInsightValue {
        IGInsightValue(name: name, period: "lifetime", values: nil,
            totalValue: IGInsightTotalValue(breakdowns: [
                IGInsightBreakdown(dimensionValues: nil, value: value)
            ]))
    }
}

// MARK: - CommentDMServiceTests

struct CommentDMServiceTests {

    /// 匹配：评论文本包含关键词（大小写不敏感）→ 返回规则
    @Test
    func testMatchKeyword() {
        let rules = [
            DMTriggerRule(keyword: "PRICE", messageTemplate: "Price here", isEnabled: true),
            DMTriggerRule(keyword: "send", messageTemplate: "Sent", isEnabled: true),
        ]
        #expect(CommentDMService.match(text: "what is the price?", rules: rules)?.keyword == "PRICE")
        #expect(CommentDMService.match(text: "please SEND me", rules: rules)?.keyword == "send")
        #expect(CommentDMService.match(text: "nice photo", rules: rules) == nil)
    }

    /// 禁用的规则不参与匹配
    @Test
    func testMatchDisabledRuleSkipped() {
        let rules = [
            DMTriggerRule(keyword: "PRICE", messageTemplate: "P", isEnabled: false),
        ]
        #expect(CommentDMService.match(text: "PRICE", rules: rules) == nil)
    }

    /// 模板渲染：{username} 替换 + 问候语变体前缀
    @Test
    func testRenderTemplate() {
        var rng = SeededRandom(seed: 1)
        let message = CommentDMService.render(
            template: "{username} 谢谢询问！价格在这里 👉 https://x", username: "alice", rng: &rng)
        #expect(message.contains("@alice"))
        #expect(message.contains("价格在这里"))
        // 变体前缀存在（Hi/Hey/Hello/Hi there）
        let prefixes = ["Hi ", "Hey ", "Hello ", "Hi there "]
        #expect(prefixes.contains { message.hasPrefix($0) })
    }

    /// 模板已含问候语 → 不再重复加前缀
    @Test
    func testRenderNoDuplicateGreeting() {
        var rng = SeededRandom(seed: 2)
        let message = CommentDMService.render(
            template: "Hi {username} welcome!", username: "bob", rng: &rng)
        #expect(message.hasPrefix("Hi @bob"))
        #expect(!message.contains("Hi Hi"))
    }

    /// 24h 窗口：近期评论通过，过期评论拒绝
    @Test
    func testWindow() {
        let now = Date()
        let iso = ISO8601DateFormatter()
        let recent = iso.string(from: now.addingTimeInterval(-3600))
        let old = iso.string(from: now.addingTimeInterval(-48 * 3600))
        #expect(CommentDMService.isWithinWindow(commentTimestamp: recent))
        #expect(!CommentDMService.isWithinWindow(commentTimestamp: old))
        #expect(!CommentDMService.isWithinWindow(commentTimestamp: nil))
        #expect(!CommentDMService.isWithinWindow(commentTimestamp: "not-a-date"))
    }
}

// MARK: - MilestoneServiceTests

struct MilestoneServiceTests {

    private func makePost(id: Int, type: MediaPostType, likes: Int, comments: Int = 0, day: Int) -> MediaPost {
        let cal = Calendar.current
        let date = cal.date(byAdding: .day, value: day, to: cal.startOfDay(for: Date()))!
        return MediaPost(id: Int64(id), accountId: 1, igMediaID: "ms-\(id)",
            type: type, date: date, likes: likes, comments: comments,
            caption: "p\(id)", mediaURL: nil, permalink: nil)
    }

    private func makeSnapshot(day: Int, followers: Int) -> Snapshot {
        let cal = Calendar.current
        let date = cal.date(byAdding: .day, value: day, to: cal.startOfDay(for: Date()))!
        return Snapshot(id: nil, accountId: 1, followersCount: followers,
            followingCount: 100, mediaCount: 10, engagementRate: 0.05,
            totalLikes: 500, totalComments: 50, totalShares: 10, totalViews: 1000,
            observedAt: date, createdAt: Date())
    }

    /// 全部输入为空 → nil（调用方显示空态）
    @Test
    func testEmptyInputsNil() async {
        let service = MilestoneService()
        #expect(await service.extract(posts: [], snapshots: []) == nil)
    }

    /// 粉丝里程碑：快照序列跨过 1K/5K 阈值 → 对应事件
    @Test
    func testFollowerMilestones() async {
        let service = MilestoneService()
        let snaps = [
            makeSnapshot(day: -20, followers: 800),
            makeSnapshot(day: -10, followers: 1_200),
            makeSnapshot(day: -5, followers: 5_200),
        ]
        let result = await service.extract(posts: [], snapshots: snaps)
        let milestones = result?.events.filter { $0.kind == .followerMilestone } ?? []
        #expect(milestones.count == 2)
        #expect(milestones[0].value == 1_000)
        #expect(milestones[1].value == 5_000)
        #expect(milestones[1].date <= snaps[2].observedAt)
    }

    /// 爆帖：互动 > 均值 × 3；最佳单帖为互动最高帖
    @Test
    func testViralAndBestPost() async {
        let service = MilestoneService()
        let posts = [
            makePost(id: 1, type: .image, likes: 10, day: -10),
            makePost(id: 2, type: .image, likes: 10, day: -9),
            makePost(id: 3, type: .image, likes: 12, day: -8),
            makePost(id: 4, type: .video, likes: 100, day: -7),
        ]
        let result = await service.extract(posts: posts, snapshots: [])
        let viral = result?.events.filter { $0.kind == .viralPost } ?? []
        #expect(viral.count == 1)
        #expect(viral.first?.value == 100)
        #expect(result?.bestPost?.value == 100)
        #expect(result?.bestPost?.kind == .bestPost)
    }

    /// 全部帖子互动相同 → 无爆帖（均值×3 内），但最佳单帖存在
    @Test
    func testNoViralWhenUniform() async {
        let service = MilestoneService()
        let posts = [
            makePost(id: 1, type: .image, likes: 20, day: -5),
            makePost(id: 2, type: .image, likes: 20, day: -4),
            makePost(id: 3, type: .image, likes: 20, day: -3),
        ]
        let result = await service.extract(posts: posts, snapshots: [])
        #expect((result?.events.filter { $0.kind == .viralPost } ?? []).isEmpty)
        #expect(result?.bestPost != nil)
    }

    /// 掉粉事件：最负单日增量 Top N（按天去重）
    @Test
    func testUnfollowEvents() async {
        let service = MilestoneService()
        let snaps = [
            makeSnapshot(day: -10, followers: 1000),
            makeSnapshot(day: -9, followers: 970),   // -30
            makeSnapshot(day: -8, followers: 940),   // -30
            makeSnapshot(day: -7, followers: 900),   // -40
            makeSnapshot(day: -6, followers: 950),   // +50
        ]
        let result = await service.extract(posts: [], snapshots: snaps)
        let drops = result?.events.filter { $0.kind == .unfollowEvent } ?? []
        #expect(drops.count == 3)
        #expect(drops.first?.value == 40)
    }

    /// 最佳一周：7 日滑动净增峰值
    @Test
    func testBoostWeek() async {
        let service = MilestoneService()
        let snaps = [
            makeSnapshot(day: -20, followers: 1000),
            makeSnapshot(day: -19, followers: 1000),
            makeSnapshot(day: -18, followers: 1000),
            makeSnapshot(day: -17, followers: 1000),
            makeSnapshot(day: -16, followers: 1000),
            makeSnapshot(day: -15, followers: 1000),
            makeSnapshot(day: -14, followers: 1000),
            makeSnapshot(day: -13, followers: 1500), // 7 日窗口 +500
            makeSnapshot(day: -12, followers: 1500),
            makeSnapshot(day: -11, followers: 1500),
        ]
        let result = await service.extract(posts: [], snapshots: snaps)
        let boost = result?.events.filter { $0.kind == .boostWeek } ?? []
        #expect(boost.count == 1)
        #expect(boost.first?.value == 500)
    }

    /// 确定性：同输入两次提取 → 事件完全一致
    @Test
    func testDeterministic() async {
        let service = MilestoneService()
        let posts = [makePost(id: 1, type: .image, likes: 30, day: -3)]
        let snaps = [
            makeSnapshot(day: -5, followers: 500),
            makeSnapshot(day: -2, followers: 900),
        ]
        let a = await service.extract(posts: posts, snapshots: snaps)
        let b = await service.extract(posts: posts, snapshots: snaps)
        #expect(a?.events == b?.events)
    }

    /// 事件按日期升序
    @Test
    func testEventsSortedByDate() async {
        let service = MilestoneService()
        let posts = [
            makePost(id: 1, type: .image, likes: 5, day: -1),
            makePost(id: 2, type: .image, likes: 200, day: -30),
        ]
        let snaps = [
            makeSnapshot(day: -40, followers: 600),
            makeSnapshot(day: -10, followers: 2_000),
        ]
        let result = await service.extract(posts: posts, snapshots: snaps)
        guard let events = result?.events, events.count >= 2 else {
            #expect(Bool(false)); return
        }
        for i in 1..<events.count {
            #expect(events[i - 1].date <= events[i].date)
        }
    }
}
