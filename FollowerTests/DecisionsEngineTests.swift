//
//  DecisionsEngineTests.swift
//  FollowerTests
//
//  Growth Decision Engine 确定性单元测试 — ScoringEngine、TemplateEngine、CardGenerator。
//  所有测试均为纯计算测试，无 DB、无 async、无 @MainActor。
//

import Testing
import Foundation
@testable import Follower

// MARK: - Test Data Helpers

/// 构造 ContentStats
private func makeContentStats(
    type: ContentType = .reel,
    avgEngagement: Double = 0.05,
    growthRate: Double = 0.10,
    recentPosts: Int = 3,
    totalPosts: Int = 10
) -> ContentStats {
    ContentStats(type: type, avgEngagement: avgEngagement,
        totalPosts: totalPosts, recentPosts: recentPosts, growthRate: growthRate)
}

/// 构造 FollowerHealth
private func makeFollowerHealth(
    activeRatio: Double = 0.3,
    growth7d: Double = 50,
    growth30d: Double? = nil
) -> FollowerHealth {
    let total = 10000
    let active = Int(Double(total) * activeRatio)
    return FollowerHealth(
        activeFollowers: active,
        inactiveFollowers: total - active,
        totalFollowers: total,
        followerGrowth7d: growth7d,
        followerGrowth30d: growth30d ?? growth7d * 4,
        viewsGrowth7d: 0
    )
}

/// 构造 ImpactSummary — 默认已知转化率（followerPerLike = 0.01 → 每 100 赞 1 粉）
private func makeImpact(
    followerPerLike: Double = 0.01,
    viewsPerLike: Double = 10.0
) -> ImpactSummary {
    let rates = ImpactEstimator.ConversionRates(
        followerPerView: 0.001, followerPerLike: followerPerLike, viewsPerLike: viewsPerLike)
    return ImpactSummary(
        rates: rates,
        perPostFollowerGain: [.reel: 5.0, .carousel: 2.0, .photo: 1.0],
        perPostViewsGain: [.reel: 5000.0, .carousel: 2000.0, .photo: 1000.0]
    )
}

/// 构造 DecisionContext — 默认低信号（大部分模板不触发），按参数覆盖
private func makeContext(
    weekOverWeek: WeekOverWeek? = nil,
    reachTrend: TrendSignal = TrendSignal(firstHalf: 0, lastHalf: 0),
    profileViewsTrend: TrendSignal = TrendSignal(firstHalf: 0, lastHalf: 0),
    likesTrend: TrendSignal = TrendSignal(firstHalf: 0, lastHalf: 0),
    engagementTrend: TrendSignal = TrendSignal(firstHalf: 0, lastHalf: 0),
    typeShare: [ContentType: Double] = [:],
    topPostEngagement: Double = 0,
    topPostType: ContentType? = nil,
    lowestPostEngagement: Double = 0,
    lowEngagementPostCount: Int = 0,
    zeroEngagementPostCount: Int = 0,
    daysSinceLastPost: Int = 2,
    postsLast7d: Int = 3,
    longestGapDays: Int = 2,
    followingCount: Int = 100,
    draftCount: Int = 0,
    churnDays7d: Int = 0,
    churnPeakDay: Int = 1,
    churnPeakShare: Double = 0,
    weekendVsWeekdayRatio: Double = 0,
    secondBestHour: Int? = nil,
    secondBestUplift: Double = 1.0,
    snapshotCount: Int = 90,
    avgWeeklyPosts: Double = 3.0,
    phase: AccountPhase = .growing
) -> DecisionContext {
    DecisionContext(
        weekOverWeek: weekOverWeek ?? WeekOverWeek(
            postsThisWeek: postsLast7d, postsLastWeek: postsLast7d,
            followersThisWeek: 10, followersLastWeek: 10,
            viewsThisWeek: 100, viewsLastWeek: 100,
            engagementThisWeek: 30, engagementLastWeek: 30),
        reachTrend: reachTrend,
        profileViewsTrend: profileViewsTrend,
        likesTrend: likesTrend,
        engagementTrend: engagementTrend,
        typeShare: typeShare,
        topPostEngagement: topPostEngagement,
        topPostType: topPostType,
        lowestPostEngagement: lowestPostEngagement,
        lowEngagementPostCount: lowEngagementPostCount,
        zeroEngagementPostCount: zeroEngagementPostCount,
        daysSinceLastPost: daysSinceLastPost,
        postsLast7d: postsLast7d,
        longestGapDays: longestGapDays,
        followingCount: followingCount,
        draftCount: draftCount,
        churnDays7d: churnDays7d,
        churnPeakDay: churnPeakDay,
        churnPeakShare: churnPeakShare,
        weekendVsWeekdayRatio: weekendVsWeekdayRatio,
        secondBestHour: secondBestHour,
        secondBestUplift: secondBestUplift,
        snapshotCount: snapshotCount,
        avgWeeklyPosts: avgWeeklyPosts,
        phase: phase
    )
}

/// 构造 GrowthFeatures
private func makeFeatures(
    contentStats: [(ContentType, ContentStats)] = [(.reel, makeContentStats())],
    followerHealth: FollowerHealth = makeFollowerHealth(),
    fatigueIndices: [(ContentType, FatigueIndex)] = [],
    impact: ImpactSummary = makeImpact(),
    context: DecisionContext = makeContext()
) -> GrowthFeatures {
    GrowthFeatures(
        contentPerformance: Dictionary(uniqueKeysWithValues: contentStats),
        followerHealth: followerHealth,
        fatigueIndices: Dictionary(uniqueKeysWithValues: fatigueIndices),
        impact: impact,
        context: context
    )
}

/// 构造 GrowthScores
private func makeScores(
    contentScores: [(ContentType, Double)] = [(.reel, 0.87)]
) -> GrowthScores {
    GrowthScores(
        contentScores: contentScores,
        growthHealth: 0.5,
        recoveryNeeded: 0.3,
        fatiguedTypes: []
    )
}

// MARK: - ScoringEngine Tests

struct ScoringEngineTests {

    /// 高互动 + 正增长 + 无疲劳 → 得分 > 0.5
    @Test
    func testScoreContentType_HighEngagement_ReturnsHighScore() {
        let stats = makeContentStats(avgEngagement: 500, growthRate: 0.10)
        let score = ScoringEngine.scoreContentType(stats, maxEngagement: 500, fatigue: 0.0)
        // relEng=1.0, relGrowth=(0.10+1)/2=0.55 → 0.5+0.165+0.2 = 0.865
        #expect(abs(score - 0.865) < 1e-9)
        #expect(score > 0.5)
    }

    /// 零互动 → 仅增长与基线分量
    @Test
    func testScoreContentType_ZeroEngagement() {
        let stats = makeContentStats(avgEngagement: 0.0, growthRate: 0.0)
        let score = ScoringEngine.scoreContentType(stats, maxEngagement: 0.0, fatigue: 0.0)
        #expect(abs(score - 0.35) < 1e-9)
    }

    /// 疲劳惩罚 → 得分更低
    @Test
    func testScoreContentType_FatiguePenalty_ReducesScore() {
        let stats = makeContentStats(avgEngagement: 100, growthRate: 0.10)
        let noFatigue = ScoringEngine.scoreContentType(stats, maxEngagement: 200, fatigue: 0.0)
        let withFatigue = ScoringEngine.scoreContentType(stats, maxEngagement: 200, fatigue: 0.3)
        #expect(withFatigue < noFatigue)
        #expect(abs(noFatigue - withFatigue - 0.06) < 1e-9)
    }

    /// 得分天然有界 [0, 1]
    @Test
    func testScoreContentType_BoundedToZeroOne() {
        let high = ScoringEngine.scoreContentType(
            makeContentStats(avgEngagement: 1000, growthRate: 1.0), maxEngagement: 100, fatigue: 0.0)
        #expect(high <= 1.0)
        let low = ScoringEngine.scoreContentType(
            makeContentStats(avgEngagement: 0.0, growthRate: -1.0), maxEngagement: 100, fatigue: 1.0)
        #expect(low >= 0.0)
    }

    /// 综合评分按分数降序，reel 最高
    @Test
    func testScore_ReturnsSortedContentScores() {
        let features = makeFeatures(contentStats: [
            (.reel, makeContentStats(type: .reel, avgEngagement: 500)),
            (.carousel, makeContentStats(type: .carousel, avgEngagement: 100)),
            (.photo, makeContentStats(type: .photo, avgEngagement: 20)),
        ])
        let scores = ScoringEngine.score(features)
        #expect(scores.contentScores.count == 3)
        for i in 0..<(scores.contentScores.count - 1) {
            #expect(scores.contentScores[i].1 >= scores.contentScores[i + 1].1)
        }
        #expect(scores.contentScores.first?.0 == .reel)
    }
}

// MARK: - TemplateEngine Tests

struct TemplateEngineTests {

    /// boostTopType：最高分类型 + 有单帖收益 → 触发，收益 = 2 × 单帖收益
    @Test
    func testBoostTopTypeTriggered() {
        let features = makeFeatures()
        let candidates = TemplateEngine.candidates(features: features, scores: makeScores())
        let boost = candidates.first { $0.template.id == "boostTopType" }
        #expect(boost != nil)
        #expect(boost?.impact.followerGain == 10)  // 2 × 5.0
        #expect(boost?.impact.viewsGain == 10000)  // 2 × 5000
    }

    /// 无单帖收益（转化率 0）→ 不触发
    @Test
    func testBoostTopTypeNoGainNoTrigger() {
        let impact = makeImpact(followerPerLike: 0)
        let features = makeFeatures(impact: impact)
        let candidates = TemplateEngine.candidates(features: features, scores: makeScores())
        #expect(candidates.first { $0.template.id == "boostTopType" } == nil)
    }

    /// 时间类建议已移除（v1.2：小样本时段推断有误导风险，建议体系不再包含时间指导）
    @Test
    func testTimingTemplatesRemoved() {
        let features = makeFeatures(impact: makeImpact())
        let candidates = TemplateEngine.candidates(features: features, scores: makeScores())
        #expect(!candidates.contains { $0.template.type == .timing }, "时间类模板应全部移除")
    }

    /// inactiveWakeup：存在不活跃粉丝 → 触发，收益 = 10% 不活跃数
    @Test
    func testInactiveWakeupTriggered() {
        let features = makeFeatures(followerHealth: makeFollowerHealth(activeRatio: 0.2))
        let candidates = TemplateEngine.candidates(features: features, scores: makeScores())
        let wake = candidates.first { $0.template.id == "inactiveWakeup" }
        #expect(wake != nil)
        #expect(wake?.impact.followerGain == 800)  // 8000 × 10%
    }

    /// growthSlowdown：7 日速率 < 30 日一半 → 触发
    @Test
    func testGrowthSlowdownTriggered() {
        let health = makeFollowerHealth(activeRatio: 1.0, growth7d: 20, growth30d: 100)
        let features = makeFeatures(followerHealth: health)
        let candidates = TemplateEngine.candidates(features: features, scores: makeScores())
        let slow = candidates.first { $0.template.id == "growthSlowdown" }
        #expect(slow != nil)
        #expect(slow?.impact.followerGain == 20)  // (100-20)/4
    }

    /// 增长正常 → 不触发 slowdown
    @Test
    func testGrowthSlowdownNotTriggeredWhenHealthy() {
        let health = makeFollowerHealth(activeRatio: 1.0, growth7d: 60, growth30d: 100)
        let features = makeFeatures(followerHealth: health)
        #expect(!TemplateEngine.candidates(features: features, scores: makeScores()).contains { $0.template.id == "growthSlowdown" })
    }

    /// postingGap：断更 > 7 天 → 触发
    @Test
    func testPostingGapTriggered() {
        let features = makeFeatures(context: makeContext(daysSinceLastPost: 10))
        #expect(TemplateEngine.candidates(features: features, scores: makeScores()).contains { $0.template.id == "postingGap" })
    }

    /// draftBacklog：草稿 ≥ 3 → 触发
    @Test
    func testDraftBacklogTriggered() {
        let features = makeFeatures(context: makeContext(draftCount: 3))
        #expect(TemplateEngine.candidates(features: features, scores: makeScores()).contains { $0.template.id == "draftBacklog" })

        let none = makeFeatures(context: makeContext(draftCount: 1))
        #expect(!TemplateEngine.candidates(features: none, scores: makeScores()).contains { $0.template.id == "draftBacklog" })
    }

    /// churnWarning：近 7 天 ≥ 3 天净取关 → 触发
    @Test
    func testChurnWarningTriggered() {
        let features = makeFeatures(context: makeContext(churnDays7d: 3))
        #expect(TemplateEngine.candidates(features: features, scores: makeScores()).contains { $0.template.id == "churnWarning" })
    }

    /// 全空数据 → 无内容类候选（不崩溃，引导类除外）
    @Test
    func testEmptyDataNoContentCandidates() {
        let features = makeFeatures(
            contentStats: [],
            followerHealth: makeFollowerHealth(activeRatio: 1.0, growth7d: 60, growth30d: 100),
            impact: makeImpact(),
            context: makeContext(postsLast7d: 0)
        )
        let candidates = TemplateEngine.candidates(features: features, scores: makeScores(contentScores: []))
        // 无帖子 → 内容类模板不生成；仅健康/引导类
        #expect(candidates.allSatisfy { $0.template.type != .content })
        #expect(!candidates.isEmpty)
    }
}

// MARK: - AccountPhase Tests

struct AccountPhaseTests {

    /// 四态判定：viral / declining / stagnant / growing 边界
    @Test
    func testClassifyPhaseAllStates() {
        // viral：本周 ≥ 30 日周均 × 2
        #expect(FeatureExtractor.classifyPhase(followersThisWeek: 200, weeklyRate30: 50) == .viral)
        #expect(FeatureExtractor.classifyPhase(followersThisWeek: 99, weeklyRate30: 50) == .growing)
        // declining：负增长
        #expect(FeatureExtractor.classifyPhase(followersThisWeek: -1, weeklyRate30: 50) == .declining)
        // declining：本周 < 30 日周均 × 0.5
        #expect(FeatureExtractor.classifyPhase(followersThisWeek: 20, weeklyRate30: 50) == .declining)
        // stagnant：本周 ≈ 0
        #expect(FeatureExtractor.classifyPhase(followersThisWeek: 2, weeklyRate30: 50) == .stagnant)
        #expect(FeatureExtractor.classifyPhase(followersThisWeek: 30, weeklyRate30: 50) == .growing)
    }

    /// 无 30 日速率 → 负增长仍判 declining，其余 growing
    @Test
    func testClassifyPhaseNoRate() {
        #expect(FeatureExtractor.classifyPhase(followersThisWeek: -5, weeklyRate30: 0) == .declining)
        #expect(FeatureExtractor.classifyPhase(followersThisWeek: 10, weeklyRate30: 0) == .growing)
    }
}

// MARK: - Phase 加权精选 Tests

struct PhaseWeightingTests {

    /// 下滑期 → 预警类模板加权后进精选（不同状态 → 不同决策）
    @Test
    func testDecliningPhase_BoostsWarnings() {
        let declining = makeFeatures(
            contentStats: [(.reel, makeContentStats(type: .reel, avgEngagement: 500, growthRate: -0.4))],
            followerHealth: makeFollowerHealth(activeRatio: 0.8, growth7d: 60, growth30d: 100),
            context: makeContext(
                engagementTrend: TrendSignal(firstHalf: 100, lastHalf: 50),
                churnDays7d: 4,
                phase: .declining
            )
        )
        let growing = makeFeatures(
            contentStats: [(.reel, makeContentStats(type: .reel, avgEngagement: 500, growthRate: 0.4))],
            followerHealth: makeFollowerHealth(activeRatio: 0.8, growth7d: 60, growth30d: 100),
            context: makeContext(
                engagementTrend: TrendSignal(firstHalf: 50, lastHalf: 100),
                churnDays7d: 0,
                phase: .growing
            )
        )
        let decliningTop = CardGenerator.generate(scores: makeScores(), features: declining).topSuggestions
        let growingTop = CardGenerator.generate(scores: makeScores(), features: growing).topSuggestions

        // 下滑期精选应包含趋势预警（churnWarning 加权 +25）
        #expect(decliningTop.contains { $0.template.id == "churnWarning" })
        // 增长期精选应包含加码类，且精选组合不同
        #expect(growingTop.contains { $0.template.id == "boostTopType" })
        let decliningIDs = Set(decliningTop.map(\.template.id))
        let growingIDs = Set(growingTop.map(\.template.id))
        #expect(decliningIDs != growingIDs, "不同账号状态应产生不同精选组合")
    }

    /// 加权表：同候选在不同阶段得分不同
    @Test
    func testPhaseWeightsDiffer() {
        let declining = CardGenerator.phaseWeights(for: .declining)
        let growing = CardGenerator.phaseWeights(for: .growing)
        #expect((declining["churnWarning"] ?? 0) > (growing["churnWarning"] ?? 0))
        #expect((growing["boostTopType"] ?? 0) > (declining["boostTopType"] ?? 0))
    }

    /// applyPhaseWeighting 正确加分
    @Test
    func testApplyPhaseWeighting() {
        let candidate = TemplateCandidate(template: DecisionTemplate(
            id: "churnWarning", type: .growth, icon: "a", titleKey: "k", reasonKey: "k", actionKeys: ["k"]),
            score: 80, impact: .zero)
        let weighted = CardGenerator.applyPhaseWeighting(candidates: [candidate], phase: .declining)
        #expect(weighted[0].score == 105)
    }
}

// MARK: - CardGenerator Tests

struct CardGeneratorTests {

    /// 生成结果：主列表 ≤ 4，精选类别互不重复
    @Test
    func testGenerate_TopSuggestionsCappedAtFour() {
        let features = makeFeatures(
            contentStats: [
                (.reel, makeContentStats(type: .reel, avgEngagement: 500, recentPosts: 8, totalPosts: 20)),
                (.carousel, makeContentStats(type: .carousel, avgEngagement: 300, recentPosts: 3, totalPosts: 12)),
                (.photo, makeContentStats(type: .photo, avgEngagement: 200, recentPosts: 2, totalPosts: 8)),
            ],
            followerHealth: makeFollowerHealth(activeRatio: 0.2, growth7d: 20, growth30d: 100),
            context: makeContext(
                engagementTrend: TrendSignal(firstHalf: 100, lastHalf: 60),
                daysSinceLastPost: 10,
                postsLast7d: 8,
                longestGapDays: 5,
                draftCount: 5,
                churnDays7d: 3
            )
        )
        let decisions = CardGenerator.generate(scores: makeScores(), features: features)
        #expect(decisions.topSuggestions.count <= CardGenerator.topLimit)
        #expect(!decisions.all.isEmpty)
        // 精选类别去重
        let types = Set(decisions.topSuggestions.map(\.type))
        #expect(types.count == decisions.topSuggestions.count, "精选区同一类别最多 1 条")
        // 机会分降序
        let all = decisions.all
        for i in 0..<(all.count - 1) {
            #expect(all[i].priority < all[i + 1].priority)
        }
    }

    /// 精选强信号优先：4 类别强信号充足时，弱信号（估算）全部被挤出精选
    @Test
    func testSelectTop_PrefersHighConfidence() {
        let weak1 = TemplateCandidate(template: DecisionTemplate(
            id: "w1", type: .engagement, icon: "a", titleKey: "k", reasonKey: "k", actionKeys: ["k"]),
            score: 99, impact: .zero, lowConfidence: true)
        let strong1 = TemplateCandidate(template: DecisionTemplate(
            id: "s1", type: .growth, icon: "a", titleKey: "k", reasonKey: "k", actionKeys: ["k"]),
            score: 70, impact: CardImpact(followerGain: 10, viewsGain: 0))
        let strong2 = TemplateCandidate(template: DecisionTemplate(
            id: "s2", type: .health, icon: "a", titleKey: "k", reasonKey: "k", actionKeys: ["k"]),
            score: 60, impact: .zero)
        let strong3 = TemplateCandidate(template: DecisionTemplate(
            id: "s3", type: .content, icon: "a", titleKey: "k", reasonKey: "k", actionKeys: ["k"]),
            score: 55, impact: .zero)
        let strong4 = TemplateCandidate(template: DecisionTemplate(
            id: "s4", type: .timing, icon: "a", titleKey: "k", reasonKey: "k", actionKeys: ["k"]),
            score: 50, impact: .zero)

        let selected = CardGenerator.selectTop(candidates: [weak1, strong1, strong2, strong3, strong4], limit: 4)
        #expect(selected.count == 4)
        #expect(selected.allSatisfy { !$0.lowConfidence }, "强信号充足时弱信号不进精选")
        #expect(selected.map(\.template.id).contains("s1"))
        #expect(Set(selected.map(\.template.type)).count == 4)
    }

    /// 强信号不足时弱信号补位（精选不空）
    @Test
    func testSelectTop_FillsWithWeakWhenNeeded() {
        let weak1 = TemplateCandidate(template: DecisionTemplate(
            id: "w1", type: .content, icon: "a", titleKey: "k", reasonKey: "k", actionKeys: ["k"]),
            score: 20, impact: .zero, lowConfidence: true)
        let weak2 = TemplateCandidate(template: DecisionTemplate(
            id: "w2", type: .timing, icon: "a", titleKey: "k", reasonKey: "k", actionKeys: ["k"]),
            score: 15, impact: .zero, lowConfidence: true)

        let selected = CardGenerator.selectTop(candidates: [weak1, weak2], limit: 4)
        #expect(selected.count == 2)
        #expect(selected.allSatisfy { $0.lowConfidence })
    }

    /// 精选区同类别去重：同类别多条时只保留机会分最高的一条
    @Test
    func testSelectTop_DeduplicatesByCategory() {
        let c1 = TemplateCandidate(template: DecisionTemplate(
            id: "c1", type: .content, icon: "a", titleKey: "k", reasonKey: "k", actionKeys: ["k"]),
            score: 100, impact: .zero)
        let c2 = TemplateCandidate(template: DecisionTemplate(
            id: "c2", type: .content, icon: "a", titleKey: "k", reasonKey: "k", actionKeys: ["k"]),
            score: 95, impact: .zero)
        let t1 = TemplateCandidate(template: DecisionTemplate(
            id: "t1", type: .timing, icon: "a", titleKey: "k", reasonKey: "k", actionKeys: ["k"]),
            score: 90, impact: .zero)
        let g1 = TemplateCandidate(template: DecisionTemplate(
            id: "g1", type: .growth, icon: "a", titleKey: "k", reasonKey: "k", actionKeys: ["k"]),
            score: 80, impact: .zero)
        let h1 = TemplateCandidate(template: DecisionTemplate(
            id: "h1", type: .health, icon: "a", titleKey: "k", reasonKey: "k", actionKeys: ["k"]),
            score: 70, impact: .zero)

        let selected = CardGenerator.selectTop(candidates: [c1, c2, t1, g1, h1], limit: 4)
        #expect(selected.count == 4)
        #expect(selected.map(\.template.id).contains("c1"))
        #expect(!selected.map(\.template.id).contains("c2"), "同类别只保留最高分")
        #expect(Set(selected.map(\.template.type)).count == 4, "4 条来自 4 个类别")
    }

    /// 数据充足时建议总量 ≥ 6（主列表 + 折叠区）
    @Test
    func testGenerate_MultipleTriggers_ProducesManySuggestions() {
        let features = makeFeatures(
            contentStats: [
                (.reel, makeContentStats(type: .reel, avgEngagement: 500, recentPosts: 8, totalPosts: 20)),
                (.photo, makeContentStats(type: .photo, avgEngagement: 50, recentPosts: 1, totalPosts: 5)),
            ],
            followerHealth: makeFollowerHealth(activeRatio: 0.2, growth7d: 20, growth30d: 100),
            context: makeContext(
                engagementTrend: TrendSignal(firstHalf: 100, lastHalf: 60),
                daysSinceLastPost: 9,
                postsLast7d: 8,
                longestGapDays: 4,
                draftCount: 4,
                churnDays7d: 3
            )
        )
        let decisions = CardGenerator.generate(scores: makeScores(), features: features)
        #expect(decisions.all.count >= 6)
    }

    /// 低信号数据 → 弱档全量生成（≥10 条，主列表 + 折叠区），机会分排序
    @Test
    func testGenerate_LowSignal_ManySuggestions() {
        let features = makeFeatures(
            contentStats: [(.reel, makeContentStats())],
            followerHealth: makeFollowerHealth(activeRatio: 0.5, growth7d: 60, growth30d: 100),
            context: makeContext()
        )
        let decisions = CardGenerator.generate(scores: makeScores(), features: features)
        let ids = Set(decisions.all.map(\.template.id))
        #expect(ids.contains("boostTopType"))
        #expect(decisions.all.count >= 10, "低信号也应生成全部弱档建议")
        // 弱档有估算标签，强档没有
        #expect(decisions.all.contains { $0.lowConfidence })
        #expect(decisions.all.contains { !$0.lowConfidence })
    }

    /// 机会分排序：高优先模板（boostTopType 100 分）排在低优先（growthTarget 35 分）前
    @Test
    func testGenerate_SortedByOpportunityScore() {
        let features = makeFeatures(context: makeContext(postsLast7d: 8))
        let decisions = CardGenerator.generate(scores: makeScores(), features: features)
        let all = decisions.all
        let boostIndex = all.firstIndex { $0.template.id == "boostTopType" }
        let targetIndex = all.firstIndex { $0.template.id == "growthTarget" }
        if let boostIndex, let targetIndex {
            #expect(boostIndex < targetIndex)
        }
    }

    /// 空数据 → 仅引导类建议（dataCoverage），不崩溃、不硬凑
    @Test
    func testGenerate_EmptyData_GuideOnly() {
        let features = makeFeatures(
            contentStats: [],
            followerHealth: makeFollowerHealth(activeRatio: 1.0, growth7d: 60, growth30d: 100),
            impact: makeImpact(),
            context: makeContext(postsLast7d: 0)
        )
        let decisions = CardGenerator.generate(scores: makeScores(contentScores: []), features: features)
        let ids = Set(decisions.all.map(\.template.id))
        #expect(ids.contains("dataCoverage"), "空数据应有数据积累引导")
        #expect(decisions.all.count <= 3, "空数据不硬凑建议")
    }

    /// 模板 id 全局唯一（注册表完整性）
    @Test
    func testTemplateIDsUnique() {
        let features = makeFeatures(
            contentStats: [
                (.reel, makeContentStats(type: .reel, avgEngagement: 500, recentPosts: 8, totalPosts: 20)),
                (.carousel, makeContentStats(type: .carousel, avgEngagement: 300, recentPosts: 3, totalPosts: 12)),
                (.photo, makeContentStats(type: .photo, avgEngagement: 200, recentPosts: 2, totalPosts: 8)),
            ],
            followerHealth: makeFollowerHealth(activeRatio: 0.1, growth7d: 20, growth30d: 100),
            context: makeContext(
                reachTrend: TrendSignal(firstHalf: 100, lastHalf: 60),
                profileViewsTrend: TrendSignal(firstHalf: 100, lastHalf: 60),
                engagementTrend: TrendSignal(firstHalf: 100, lastHalf: 60),
                typeShare: [.reel: 0.5, .photo: 0.3, .carousel: 0.2],
                topPostEngagement: 2000, topPostType: .reel,
                lowEngagementPostCount: 4,
                zeroEngagementPostCount: 1,
                daysSinceLastPost: 10,
                postsLast7d: 8,
                longestGapDays: 5,
                followingCount: 9000,
                draftCount: 5,
                churnDays7d: 3,
                weekendVsWeekdayRatio: 0.4,
                secondBestHour: 15, secondBestUplift: 1.3
            )
        )
        let decisions = CardGenerator.generate(scores: makeScores(), features: features)
        let ids = decisions.all.map { $0.template.id }
        #expect(Set(ids).count == ids.count, "模板 id 应唯一")
        #expect(ids.count >= 6, "高信号数据应触发多个模板")
    }
}
