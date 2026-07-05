//
//  DecisionsEngineTests.swift
//  FollowerTests
//
//  Growth Decision Engine 确定性单元测试 — 覆盖 ScoringEngine 和 CardGenerator 的纯函数逻辑。
//  所有测试均为纯计算测试，无 DB、无 async、无 @MainActor。
//  测试范围：
//    - ScoringEngine: 内容评分、增长健康、恢复需求、综合评分、疲劳检测
//    - CardGenerator: Primary / Alert / Recovery / Insight 四类卡片生成与排序
//

import Testing
import Foundation
@testable import Follower

// MARK: - Test Data Helpers

/// 构造 ContentStats 实例，用于 ScoringEngine 和 CardGenerator 测试
private func makeContentStats(
    type: ContentType = .reel,
    avgEngagement: Double = 0.05,
    growthRate: Double = 0.10,
    recentPosts: Int = 3
) -> ContentStats {
    ContentStats(
        type: type,
        avgEngagement: avgEngagement,
        totalPosts: 10,
        recentPosts: recentPosts,
        growthRate: growthRate
    )
}

/// 构造 FollowerHealth 实例，通过 activeRatio 和 growth7d 灵活控制测试参数
private func makeFollowerHealth(
    activeRatio: Double = 0.3,
    growth7d: Double = 50
) -> FollowerHealth {
    let total = 10000
    let active = Int(Double(total) * activeRatio)
    return FollowerHealth(
        activeFollowers: active,
        inactiveFollowers: total - active,
        totalFollowers: total,
        followerGrowth7d: growth7d,
        followerGrowth30d: growth7d * 4
    )
}

/// 构造 GrowthFeatures 实例，支持按参数覆盖各维度
private func makeFeatures(
    contentStats: [(ContentType, ContentStats)] = [(.reel, makeContentStats())],
    followerHealth: FollowerHealth = makeFollowerHealth(),
    timingProfile: TimingProfile = TimingProfile(
        bestHours: "19:00–21:00",
        worstHours: "03:00–06:00",
        bestDay: 4
    ),
    fatigueIndices: [(ContentType, FatigueIndex)] = []
) -> GrowthFeatures {
    let perf = Dictionary(uniqueKeysWithValues: contentStats)
    let fatigue = Dictionary(uniqueKeysWithValues: fatigueIndices)
    return GrowthFeatures(
        contentPerformance: perf,
        followerHealth: followerHealth,
        timingProfile: timingProfile,
        fatigueIndices: fatigue
    )
}

/// 构造 GrowthScores 实例，用于 CardGenerator 测试
private func makeScores(
    contentScores: [(ContentType, Double)] = [(.reel, 0.87)],
    fatiguedTypes: [ContentType] = [],
    recoveryNeeded: Double = 0.3
) -> GrowthScores {
    GrowthScores(
        contentScores: contentScores,
        growthHealth: 0.5,
        recoveryNeeded: recoveryNeeded,
        fatiguedTypes: fatiguedTypes
    )
}

// MARK: - ScoringEngine Tests

/// Unit tests for ScoringEngine — 纯函数计算验证
/// 覆盖：content scoring / growth health / recovery needed / 综合评分 / 疲劳检测
struct ScoringEngineTests {

    // MARK: scoreContentType

    /// 高互动率 + 正增长 + 无疲劳 → 得分 > 0.5
    @Test
    func testScoreContentType_HighEngagement_ReturnsHighScore() {
        let stats = makeContentStats(avgEngagement: 0.05, growthRate: 0.10)
        let score = ScoringEngine.scoreContentType(stats, fatigue: 0.0)
        // raw = 0.05*100*0.5 + 0.10*0.3 - 0*0.2 = 2.5 + 0.03 = 2.53 → clamped 1.0
        #expect(score > 0.5)
    }

    /// 零互动率 → 得分为 0
    @Test
    func testScoreContentType_ZeroEngagement_ReturnsZero() {
        let stats = makeContentStats(avgEngagement: 0.0, growthRate: 0.0)
        let score = ScoringEngine.scoreContentType(stats, fatigue: 0.0)
        #expect(score == 0.0)
    }

    /// 疲劳惩罚 → 同样互动率下，有疲劳的得分更低
    @Test
    func testScoreContentType_FatiguePenalty_ReducesScore() {
        // 使用较低数值避免 clamping 干扰疲劳差异
        let stats = makeContentStats(avgEngagement: 0.01, growthRate: 0.10)
        let scoreNoFatigue = ScoringEngine.scoreContentType(stats, fatigue: 0.0)
        let scoreWithFatigue = ScoringEngine.scoreContentType(stats, fatigue: 0.3)
        // raw_no = 0.01*100*0.5 + 0.10*0.3 = 0.5 + 0.03 = 0.53
        // raw_fatigue = 0.53 - 0.3*0.2 = 0.53 - 0.06 = 0.47
        #expect(scoreWithFatigue < scoreNoFatigue)
    }

    /// 得分为 0-1 之间，不会超出范围（clamped）
    @Test
    func testScoreContentType_ClampedToZeroOne() {
        // 极高值 → 应 clamp 到 1.0
        let highStats = makeContentStats(avgEngagement: 1.0, growthRate: 1.0)
        let highScore = ScoringEngine.scoreContentType(highStats, fatigue: 0.0)
        #expect(highScore <= 1.0)
        #expect(highScore >= 0.0)

        // 极低值（负增长 + 高疲劳） → 应 clamp 到 0.0
        let lowStats = makeContentStats(avgEngagement: 0.0, growthRate: -1.0)
        let lowScore = ScoringEngine.scoreContentType(lowStats, fatigue: 1.0)
        #expect(lowScore >= 0.0)
        #expect(lowScore <= 1.0)
    }

    // MARK: scoreGrowthHealth

    /// 高活跃比 + 高增长率 → 健康得分 > 0.5
    @Test
    func testScoreGrowthHealth_HighActive_ReturnsHighScore() {
        // activeRatio = 0.8, growth7d = 85 → growth=min(0.85,1)*0.4=0.34, active=0.8*0.6=0.48, total=0.82
        let health = makeFollowerHealth(activeRatio: 0.8, growth7d: 85)
        let score = ScoringEngine.scoreGrowthHealth(health)
        #expect(score > 0.5)
    }

    // MARK: scoreRecoveryNeeded

    /// activeRatio < 0.5 → recoveryNeeded > 0
    @Test
    func testScoreRecoveryNeeded_LowActive_ReturnsPositive() {
        let health = makeFollowerHealth(activeRatio: 0.3)
        let recovery = ScoringEngine.scoreRecoveryNeeded(health)
        // (0.5 - 0.3) * 2.0 = 0.4
        #expect(recovery > 0.0)
    }

    /// activeRatio >= 0.5 → recoveryNeeded = 0
    @Test
    func testScoreRecoveryNeeded_HighActive_ReturnsZero() {
        let health = makeFollowerHealth(activeRatio: 0.5)
        let recovery = ScoringEngine.scoreRecoveryNeeded(health)
        #expect(recovery == 0.0)

        let highHealth = makeFollowerHealth(activeRatio: 0.8)
        let highRecovery = ScoringEngine.scoreRecoveryNeeded(highHealth)
        #expect(highRecovery == 0.0)
    }

    // MARK: score (综合评分)

    /// 完整评分流水线 → 返回的 contentScores 按分数降序排列
    @Test
    func testScore_ReturnsSortedContentScores() {
        // reel (low engagement) < carousel (medium) < photo (high) — but we reverse; carousel and photo will rank higher
        // 使用不同互动率创建明确差异
        let reelStats = makeContentStats(type: .reel, avgEngagement: 0.10, growthRate: 0.20)
        let carouselStats = makeContentStats(type: .carousel, avgEngagement: 0.01, growthRate: 0.05)
        let photoStats = makeContentStats(type: .photo, avgEngagement: 0.001, growthRate: 0.0)

        let features = makeFeatures(
            contentStats: [(.reel, reelStats), (.carousel, carouselStats), (.photo, photoStats)]
        )

        let scores = ScoringEngine.score(features)

        #expect(scores.contentScores.count == 3)
        // 验证降序排列：前一个 >= 后一个
        for i in 0..<(scores.contentScores.count - 1) {
            #expect(scores.contentScores[i].1 >= scores.contentScores[i + 1].1)
        }
    }

    /// 疲劳类型被正确检测
    @Test
    func testScore_DetectsFatiguedTypes() {
        // carousel: posts7d = 7 (> 5) → fatigued
        // reel: posts7d = 3 (<= 5) → not fatigued
        let fatigueIndices: [(ContentType, FatigueIndex)] = [
            (.carousel, FatigueIndex(contentType: .carousel, posts7d: 7, engagementTrend: -0.28)),
            (.reel, FatigueIndex(contentType: .reel, posts7d: 3, engagementTrend: 0.12)),
        ]

        let features = makeFeatures(
            contentStats: [
                (.reel, makeContentStats(type: .reel)),
                (.carousel, makeContentStats(type: .carousel)),
            ],
            fatigueIndices: fatigueIndices
        )

        let scores = ScoringEngine.score(features)

        #expect(scores.fatiguedTypes.contains(.carousel))
        #expect(!scores.fatiguedTypes.contains(.reel))
    }
}

// MARK: - CardGenerator Tests

/// Unit tests for CardGenerator — 基于规则引擎的卡片生成验证
/// 覆盖：Primary / Alert / Recovery / Insight 四类卡片生成规则与排序
struct CardGeneratorTests {

    // MARK: generate — Primary Card

    /// 高 contentScore (>0.5) → 生成 Primary card
    @Test
    func testGenerate_HighScore_ProducesPrimaryCard() {
        let scores = makeScores(contentScores: [(.reel, 0.87)])
        // 需要 features.contentPerformance 包含对应类型，primaryCard 才会生成
        let reelStats = makeContentStats(type: .reel, avgEngagement: 0.042, growthRate: 0.12)
        let features = makeFeatures(contentStats: [(.reel, reelStats)])

        let cards = CardGenerator.generate(scores: scores, features: features)

        #expect(cards.contains { $0.type == .primary })
    }

    /// 低 contentScore (<=0.5) → 不生成 Primary card
    @Test
    func testGenerate_LowScore_NoPrimaryCard() {
        let scores = makeScores(contentScores: [(.reel, 0.3)])
        let reelStats = makeContentStats(type: .reel)
        let features = makeFeatures(contentStats: [(.reel, reelStats)])

        let cards = CardGenerator.generate(scores: scores, features: features)

        #expect(!cards.contains { $0.type == .primary })
    }

    // MARK: generate — Alert Card

    /// 疲劳类型 → 生成 Alert card
    @Test
    func testGenerate_FatigueDetected_ProducesAlertCard() {
        let scores = makeScores(
            contentScores: [(.reel, 0.3)],
            fatiguedTypes: [.carousel]
        )
        let features = makeFeatures()

        let cards = CardGenerator.generate(scores: scores, features: features)

        #expect(cards.contains { $0.type == .alert })
    }

    /// 多种疲劳类型 → 每种生成一张 Alert card
    @Test
    func testGenerate_MultipleFatigue_ProducesMultipleAlertCards() {
        let scores = makeScores(
            contentScores: [(.reel, 0.3)],
            fatiguedTypes: [.carousel, .photo]
        )
        let features = makeFeatures()

        let cards = CardGenerator.generate(scores: scores, features: features)

        let alertCards = cards.filter { $0.type == .alert }
        #expect(alertCards.count == 2)
    }

    // MARK: generate — Recovery Card

    /// recoveryNeeded > 0.5 → 生成 Recovery card
    @Test
    func testGenerate_HighRecoveryNeeded_ProducesRecoveryCard() {
        let scores = makeScores(
            contentScores: [(.reel, 0.3)],
            recoveryNeeded: 0.8
        )
        let health = makeFollowerHealth(activeRatio: 0.2)
        let features = makeFeatures(followerHealth: health)

        let cards = CardGenerator.generate(scores: scores, features: features)

        #expect(cards.contains { $0.type == .recovery })
    }

    /// recoveryNeeded <= 0.5 → 不生成 Recovery card
    @Test
    func testGenerate_LowRecoveryNeeded_NoRecoveryCard() {
        let scores = makeScores(
            contentScores: [(.reel, 0.3)],
            recoveryNeeded: 0.3
        )
        let features = makeFeatures()

        let cards = CardGenerator.generate(scores: scores, features: features)

        #expect(!cards.contains { $0.type == .recovery })
    }

    // MARK: generate — Insight Card

    /// 总是生成至少一张 Insight card（无触发条件时仅 Insight）
    @Test
    func testGenerate_AlwaysProducesInsightCard() {
        // 低分、无疲劳、低恢复 → 不应生成 primary/alert/recovery，但仍生成 insight
        let scores = makeScores(
            contentScores: [(.reel, 0.3)],
            fatiguedTypes: [],
            recoveryNeeded: 0.1
        )
        let features = makeFeatures()

        let cards = CardGenerator.generate(scores: scores, features: features)

        #expect(cards.contains { $0.type == .insight })
        #expect(!cards.contains { $0.type == .primary })
        #expect(!cards.contains { $0.type == .alert })
        #expect(!cards.contains { $0.type == .recovery })
    }

    /// 全部触发条件满足时 → 仍包含 Insight card
    @Test
    func testGenerate_AllTriggersActive_StillIncludesInsightCard() {
        let reelStats = makeContentStats(type: .reel, avgEngagement: 0.042, growthRate: 0.12)
        let features = makeFeatures(
            contentStats: [(.reel, reelStats)],
            followerHealth: makeFollowerHealth(activeRatio: 0.2)
        )
        let scores = makeScores(
            contentScores: [(.reel, 0.87)],
            fatiguedTypes: [.carousel],
            recoveryNeeded: 0.8
        )

        let cards = CardGenerator.generate(scores: scores, features: features)

        #expect(cards.contains { $0.type == .primary })
        #expect(cards.contains { $0.type == .alert })
        #expect(cards.contains { $0.type == .recovery })
        #expect(cards.contains { $0.type == .insight })
    }

    // MARK: generate — 排序

    /// 卡片按 priority 升序排列
    @Test
    func testGenerate_CardsSortedByPriority() {
        let reelStats = makeContentStats(type: .reel, avgEngagement: 0.042, growthRate: 0.12)
        let features = makeFeatures(
            contentStats: [(.reel, reelStats)],
            followerHealth: makeFollowerHealth(activeRatio: 0.2)
        )
        let scores = makeScores(
            contentScores: [(.reel, 0.87)],
            fatiguedTypes: [.carousel],
            recoveryNeeded: 0.8
        )

        let cards = CardGenerator.generate(scores: scores, features: features)

        // 验证按 priority 升序
        for i in 0..<(cards.count - 1) {
            #expect(cards[i].priority <= cards[i + 1].priority)
        }
    }

    // MARK: generate — 边界情况

    /// 空 scores（无数据）→ 不崩溃，至少生成 Insight card
    @Test
    func testGenerate_EmptyScores_DoesNotCrash() {
        let scores = GrowthScores(
            contentScores: [],
            growthHealth: 0.0,
            recoveryNeeded: 0.0,
            fatiguedTypes: []
        )
        let features = makeFeatures()

        let cards = CardGenerator.generate(scores: scores, features: features)

        // 不崩溃且至少生成 insight
        #expect(cards.contains { $0.type == .insight })
    }

    /// 空 contentScores 且无其他触发 → 仅生成 Insight card
    @Test
    func testGenerate_NoTriggers_OnlyInsightCard() {
        let scores = GrowthScores(
            contentScores: [],
            growthHealth: 0.0,
            recoveryNeeded: 0.0,
            fatiguedTypes: []
        )
        let features = makeFeatures()

        let cards = CardGenerator.generate(scores: scores, features: features)

        #expect(cards.count == 1)
        #expect(cards[0].type == .insight)
    }
}
