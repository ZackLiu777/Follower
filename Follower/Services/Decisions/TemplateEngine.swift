//
//  TemplateEngine.swift
//  Follower
//
//  决策模板引擎（v2 — 声明式契约 + 槽位填充 + 适配校验）。
//
//  抽象设计：
//  - TemplateSpec：模板契约声明（方向 / 数据门槛 / 适用阶段 / 目标值校验）
//  - build 闭包：数据 → 槽位数字填充（决策系统输出数字，文案只留占位）
//  - 统一流水线：门槛过滤 → 语义校验 → 强弱档自动判定 → 机会分
//
//  语义校验（数字与模板契约的适配保证）：
//  - 数据门槛：minPosts / minSnapshots
//  - 方向一致性：increase → 填充值必须 > 当前实测值；decrease → 反之
//  - 收益非负：impact 不允许负数
//  - 阶段兼容：applicablePhases 不含当前 phase → 不生成
//
//  时间类模板已移除（v1.2：小样本时段推断有误导风险）。

import Foundation

// MARK: - 方向

/// 建议的方向语义 — 用于数字与模板的适配校验
enum Direction: Sendable {
    /// 增加型（提频 / 加码 / 加发）
    case increase
    /// 减少型（降频 / 暂停）
    case decrease
    /// 中性（无数量方向语义）
    case neutral
}

// MARK: - FilledTemplate

/// 槽位填充结果 — 模板 + 数字填充后的收益
struct FilledTemplate: Sendable {
    /// 渲染模板（文案 key + 参数已填数字）
    let template: DecisionTemplate
    /// 量化收益（数字校验对象）
    let impact: CardImpact
    /// 估算标记（信号不足的降级版本）
    let lowConfidence: Bool
}

// MARK: - TemplateSpec

/// 模板契约 — 声明式配置 + 数字填充闭包
struct TemplateSpec: Sendable {
    let id: String
    let type: CardType
    let icon: String
    /// 基础机会分
    let baseScore: Int
    /// 数据门槛
    let minPosts: Int
    let minSnapshots: Int
    /// 适用阶段（nil = 所有阶段）
    let applicablePhases: Set<AccountPhase>?
    /// 数量语义方向
    let direction: Direction
    /// 方向校验的目标值（如建议目标频率）；与 direction 配合
    let targetValue: ((GrowthFeatures) -> Double)?
    /// 方向校验的当前实测值（如当前周发帖数）
    let currentValue: ((GrowthFeatures) -> Double)?
    /// 数字填充 — 数据 → FilledTemplate；nil = 不生成（信号/门槛已在闭包内判断）
    let build: @Sendable (GrowthFeatures, GrowthScores) -> FilledTemplate?
}

// MARK: - TemplateRegistry

/// 模板注册表 — 36 个模板的声明式注册
enum TemplateRegistry {

    static let all: [TemplateSpec] = [
        // MARK: Content (12)
        boostTopType, rescueDecliningType, replicateViral, lowEngagementDiagnosis,
        diversifyTypes, carouselForLongContent, increaseFrequency, reduceFrequency,
        balanceWeeklyCadence, testSecondBestType, typeTrendWarning, guideComments,
        // MARK: Growth (8)
        growthSlowdown, inactiveWakeup, churnWarning, churnPeakDay,
        conversionBoost, followerQuality, topFansEngage, growthTarget,
        // MARK: Engagement (5)
        engagementDecline, replyComments, qAndA, shareRateLow, viralFollowUp,
        // MARK: Reach (4)
        reachDecline, profileViewsBoost, reachWasted, stablePublishing,
        // MARK: Health (4)
        followingRatioHigh, draftBacklog, postingGap, dataCoverage,
        // MARK: Ops (3)
        reuseViral, monthlyPlan, seriesContent,
    ]

    // ───────────────────────── Content ─────────────────────────

    /// 1. 加码最强内容类型
    static let boostTopType = TemplateSpec(
        id: "boostTopType", type: .content, icon: "flame.fill", baseScore: 100,
        minPosts: 0, minSnapshots: 0, applicablePhases: nil,
        direction: .neutral, targetValue: nil, currentValue: nil,
        build: { features, scores in
            guard let top = scores.contentScores.first, top.1 > 0.01 else { return nil }
            let name = "\(top.0)".capitalized
            let extra = recommendedExtraPosts(features)
            let (fans, views) = perPostGain(top.0, features: features)
            if fans > 0 {
                let impact = CardImpact(followerGain: Int((Double(extra) * fans).rounded()),
                    viewsGain: Int((Double(extra) * views).rounded()))
                return FilledTemplate(
                    template: tpl(id: "boostTopType", type: .content, icon: "flame.fill",
                        titleKey: Tpl.Title.boostTopType, titleArgs: [name],
                        reasonKey: Tpl.Reason.perPostGain,
                        reasonArgs: [name, ActionCard.formatCount(Int(fans.rounded()))],
                        actionKeys: [Tpl.Action.boost], actionArgsList: [["\(extra)", name]]),
                    impact: impact, lowConfidence: false)
            }
            // 转化率不足 → 数据积累中降级版
            return FilledTemplate(
                template: tpl(id: "boostTopType", type: .content, icon: "flame.fill",
                    titleKey: Tpl.Title.boostTopType, titleArgs: [name],
                    reasonKey: Tpl.Reason.insufficientData, reasonArgs: [name],
                    actionKeys: [Tpl.Action.boost], actionArgsList: [["\(extra)", name]]),
                impact: .zero, lowConfidence: true)
        })

    /// 2. 挽救下滑类型
    static let rescueDecliningType = TemplateSpec(
        id: "rescueDecliningType", type: .content, icon: "arrow.uturn.down.circle.fill", baseScore: 85,
        minPosts: 1, minSnapshots: 0, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, scores in
            guard let top = scores.contentScores.first, top.1 > 0.01 else { return nil }
            let name = "\(top.0)".capitalized
            let declinePct = pct(features.contentPerformance[top.0]?.growthRate ?? 0)
            let t = tpl(id: "rescueDecliningType", type: .content, icon: "arrow.uturn.down.circle.fill",
                titleKey: Tpl.Title.rescueDecliningType, titleArgs: [name],
                reasonKey: Tpl.Reason.typeDeclining, reasonArgs: [name, declinePct],
                actionKeys: [Tpl.Action.tryNewFormat, Tpl.Action.replyAll], actionArgsList: [[name], []])
            let isDeclining = (features.contentPerformance[top.0]?.growthRate ?? 0) < -0.2
            return FilledTemplate(template: t, impact: .zero, lowConfidence: !isDeclining)
        })

    /// 3. 复制爆款
    static let replicateViral = TemplateSpec(
        id: "replicateViral", type: .content, icon: "star.circle.fill", baseScore: 95,
        minPosts: 1, minSnapshots: 0, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            guard let type = features.context.topPostType else { return nil }
            let name = "\(type)".capitalized
            let avg = overallAvgEngagement(features)
            let multiplier = avg > 0 ? features.context.topPostEngagement / avg : 0
            let extra = recommendedExtraPosts(features)
            let t = tpl(id: "replicateViral", type: .content, icon: "star.circle.fill",
                titleKey: Tpl.Title.replicateViral, titleArgs: [name],
                reasonKey: Tpl.Reason.viral, reasonArgs: [name, String(format: "%.1f", multiplier)],
                actionKeys: [Tpl.Action.boost], actionArgsList: [["\(extra)", name]])
            guard avg > 0, features.context.topPostEngagement >= avg * 3 else {
                return FilledTemplate(template: t, impact: .zero, lowConfidence: true)
            }
            let (fans, views) = perPostGain(type, features: features)
            let impact = CardImpact(followerGain: Int((Double(extra) * fans).rounded()),
                viewsGain: Int((Double(extra) * views).rounded()))
            return FilledTemplate(template: t, impact: impact, lowConfidence: false)
        })

    /// 4. 低互动帖子诊断
    static let lowEngagementDiagnosis = TemplateSpec(
        id: "lowEngagementDiagnosis", type: .content, icon: "magnifyingglass.circle.fill", baseScore: 55,
        minPosts: 6, minSnapshots: 0, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            let posts = totalPosts(features)
            let t = tpl(id: "lowEngagementDiagnosis", type: .content, icon: "magnifyingglass.circle.fill",
                titleKey: Tpl.Title.lowEngagementDiagnosis,
                reasonKey: Tpl.Reason.lowEngage, reasonArgs: ["\(features.context.lowEngagementPostCount)"],
                actionKeys: [Tpl.Action.analyzeLow])
            let strong = features.context.lowEngagementPostCount >= 3
                && Double(features.context.lowEngagementPostCount) / Double(posts) >= 0.3
            return FilledTemplate(template: t, impact: .zero, lowConfidence: !strong)
        })

    /// 5. 内容类型多样化
    static let diversifyTypes = TemplateSpec(
        id: "diversifyTypes", type: .content, icon: "square.grid.2x2.fill", baseScore: 50,
        minPosts: 1, minSnapshots: 0, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            guard let dominant = features.context.typeShare.max(by: { $0.value < $1.value }) else { return nil }
            let name = "\(dominant.key)".capitalized
            let pctVal = Int((dominant.value * 100).rounded())
            let t = tpl(id: "diversifyTypes", type: .content, icon: "square.grid.2x2.fill",
                titleKey: Tpl.Title.diversifyTypes, titleArgs: [name, "\(pctVal)"],
                reasonKey: Tpl.Reason.dominant, reasonArgs: [name, "\(pctVal)"],
                actionKeys: [Tpl.Action.diversify], actionArgsList: [["\(pctVal)"]])
            return FilledTemplate(template: t, impact: .zero, lowConfidence: dominant.value <= 0.7)
        })

    /// 6. 长内容换格式
    static let carouselForLongContent = TemplateSpec(
        id: "carouselForLongContent", type: .content, icon: "rectangle.on.rectangle.fill", baseScore: 45,
        minPosts: 1, minSnapshots: 0, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            guard let photo = features.contentPerformance[.photo] else { return nil }
            let t = tpl(id: "carouselForLongContent", type: .content, icon: "rectangle.on.rectangle.fill",
                titleKey: Tpl.Title.carouselForLongContent,
                reasonKey: Tpl.Reason.photoWeak, reasonArgs: ["Photo", "Reel/Video", "50"],
                actionKeys: [Tpl.Action.switchFormat])
            let others = features.contentPerformance.filter { $0.key != .photo }.values.map(\.avgEngagement).max() ?? 0
            let strong = (features.context.typeShare[.photo] ?? 0) > 0.5
                && others > 0 && photo.avgEngagement < others * 0.5
            return FilledTemplate(template: t, impact: .zero, lowConfidence: !strong)
        })

    /// 7. 提升发帖频率（目标频率 = 周均 + 1）
    static let increaseFrequency = TemplateSpec(
        id: "increaseFrequency", type: .content, icon: "plus.circle.fill", baseScore: 70,
        minPosts: 4, minSnapshots: 0, applicablePhases: nil,
        direction: .increase,
        targetValue: { recommendedWeeklyTarget($0) },
        currentValue: { Double($0.context.postsLast7d) },
        build: { features, scores in
            let target = Int(recommendedWeeklyTarget(features))
            let t = tpl(id: "increaseFrequency", type: .content, icon: "plus.circle.fill",
                titleKey: Tpl.Title.increaseFrequency,
                reasonKey: Tpl.Reason.freqLow, reasonArgs: ["\(features.context.postsLast7d)"],
                actionKeys: [Tpl.Action.scheduleMore], actionArgsList: [["\(target)"]])
            let isLow = features.context.postsLast7d <= 1
            if isLow {
                let top = scores.contentScores.first?.0 ?? .reel
                let (fans, views) = perPostGain(top, features: features)
                let impact = CardImpact(followerGain: Int((Double(target - features.context.postsLast7d) * fans).rounded()),
                    viewsGain: Int((Double(target - features.context.postsLast7d) * views).rounded()))
                return FilledTemplate(template: t, impact: impact, lowConfidence: false)
            }
            return FilledTemplate(template: t, impact: .zero, lowConfidence: true)
        })

    /// 8. 降低发帖频率（目标频率 = 周均 - 2）
    static let reduceFrequency = TemplateSpec(
        id: "reduceFrequency", type: .content, icon: "minus.circle.fill", baseScore: 75,
        minPosts: 10, minSnapshots: 0, applicablePhases: nil,
        direction: .decrease,
        targetValue: { Double(max(3, Int($0.context.avgWeeklyPosts.rounded()) - 2)) },
        currentValue: { Double($0.context.postsLast7d) },
        build: { features, _ in
            let target = max(3, Int(features.context.avgWeeklyPosts.rounded()) - 2)
            let t = tpl(id: "reduceFrequency", type: .content, icon: "minus.circle.fill",
                titleKey: Tpl.Title.reduceFrequency,
                reasonKey: Tpl.Reason.freqHigh, reasonArgs: ["\(features.context.postsLast7d)"],
                actionKeys: [Tpl.Action.reduceTo], actionArgsList: [["\(target)"]])
            let strong = features.context.postsLast7d >= 6
                && features.context.engagementTrend.direction == .down
            return FilledTemplate(template: t, impact: .zero, lowConfidence: !strong)
        })

    /// 9. 均匀发帖节奏
    static let balanceWeeklyCadence = TemplateSpec(
        id: "balanceWeeklyCadence", type: .content, icon: "calendar.badge.plus", baseScore: 60,
        minPosts: 4, minSnapshots: 0, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            let days = clamp(Int(features.context.avgWeeklyPosts.rounded()), 2, 5)
            let t = tpl(id: "balanceWeeklyCadence", type: .content, icon: "calendar.badge.plus",
                titleKey: Tpl.Title.balanceWeeklyCadence,
                reasonKey: Tpl.Reason.cadence, reasonArgs: ["\(features.context.longestGapDays)"],
                actionKeys: [Tpl.Action.spreadCadence], actionArgsList: [["\(days)"]])
            return FilledTemplate(template: t, impact: .zero, lowConfidence: features.context.longestGapDays < 4)
        })

    /// 10. 测试次优类型
    static let testSecondBestType = TemplateSpec(
        id: "testSecondBestType", type: .content, icon: "flask.fill", baseScore: 40,
        minPosts: 1, minSnapshots: 0, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, scores in
            guard scores.contentScores.count >= 2 else { return nil }
            let name = "\(scores.contentScores[1].0)".capitalized
            let t = tpl(id: "testSecondBestType", type: .content, icon: "flask.fill",
                titleKey: Tpl.Title.testSecondBestType, titleArgs: [name],
                reasonKey: Tpl.Reason.secondType, reasonArgs: [name],
                actionKeys: [Tpl.Action.testOne], actionArgsList: [[name]])
            let strong = scores.contentScores[1].1 > 0.4
                && (features.contentPerformance[scores.contentScores[1].0]?.avgEngagement ?? 0) > 0
            return FilledTemplate(template: t, impact: .zero, lowConfidence: !strong)
        })

    /// 11. 类型趋势预警
    static let typeTrendWarning = TemplateSpec(
        id: "typeTrendWarning", type: .content, icon: "chart.line.downtrend.xyaxis", baseScore: 65,
        minPosts: 3, minSnapshots: 0, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, scores in
            guard let top = scores.contentScores.first?.0 else { return nil }
            let nonTop = features.contentPerformance
                .filter { $0.key != top && $0.value.totalPosts >= 3 }
                .sorted { $0.key.rawValue < $1.key.rawValue }
            guard let first = nonTop.first else { return nil }
            let name = "\(first.key)".capitalized
            let t = tpl(id: "typeTrendWarning", type: .content, icon: "chart.line.downtrend.xyaxis",
                titleKey: Tpl.Title.typeTrendWarning, titleArgs: [name],
                reasonKey: Tpl.Reason.typeWarning, reasonArgs: [name, pct(first.value.growthRate)],
                actionKeys: [Tpl.Action.pauseType], actionArgsList: [[name]])
            return FilledTemplate(template: t, impact: .zero, lowConfidence: first.value.growthRate >= -0.3)
        })

    /// 12. 高赞低评论引导
    static let guideComments = TemplateSpec(
        id: "guideComments", type: .content, icon: "bubble.left.and.bubble.right.fill", baseScore: 55,
        minPosts: 4, minSnapshots: 0, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { _, _ in
            FilledTemplate(
                template: tpl(id: "guideComments", type: .content, icon: "bubble.left.and.bubble.right.fill",
                    titleKey: Tpl.Title.guideComments,
                    reasonKey: Tpl.Reason.highLikesLowComments,
                    actionKeys: [Tpl.Action.askComments]),
                impact: .zero, lowConfidence: false)
        })

    // ───────────────────────── Growth ─────────────────────────

    /// 13. 增长放缓回补
    static let growthSlowdown = TemplateSpec(
        id: "growthSlowdown", type: .growth, icon: "chart.line.downtrend.xyaxis", baseScore: 85,
        minPosts: 0, minSnapshots: 2, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            let health = features.followerHealth
            let gap = Int(((health.followerGrowth30d - health.followerGrowth7d) / 4).rounded())
            let pctOfRate = health.followerGrowth30d > 0
                ? Int((100 * health.followerGrowth7d / health.followerGrowth30d).rounded()) : 100
            let t = tpl(id: "growthSlowdown", type: .growth, icon: "chart.line.downtrend.xyaxis",
                titleKey: Tpl.Title.growthSlowdown,
                reasonKey: Tpl.Reason.growthSlowdown, reasonArgs: ["\(gap)", "\(pctOfRate)%"],
                actionKeys: [Tpl.Action.boost, Tpl.Action.engageTopFans],
                actionArgsList: [["\(recommendedExtraPosts(features))", "Reel"], []])
            let strong = health.followerGrowth30d > 0 && health.followerGrowth7d < health.followerGrowth30d * 0.5
            if strong {
                let vGain = features.impact.rates.followerPerView > 0
                    ? Int((Double(gap) / features.impact.rates.followerPerView).rounded()) : 0
                return FilledTemplate(template: t, impact: CardImpact(followerGain: gap, viewsGain: vGain), lowConfidence: false)
            }
            return FilledTemplate(template: t, impact: .zero, lowConfidence: true)
        })

    /// 14. 不活跃粉丝唤醒（唤醒比例数据驱动）
    static let inactiveWakeup = TemplateSpec(
        id: "inactiveWakeup", type: .growth, icon: "arrow.up.heart.fill", baseScore: 75,
        minPosts: 0, minSnapshots: 1, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            let health = features.followerHealth
            guard health.inactiveFollowers > 0 else { return nil }
            let pct = Int((1.0 - health.activeRatio) * 100)
            let wakeRatio = wakeupRatio(features)
            let target = Int((Double(health.inactiveFollowers) * wakeRatio).rounded())
            let vGain = features.impact.rates.followerPerView > 0
                ? Int((Double(target) / features.impact.rates.followerPerView).rounded()) : 0
            let impact = CardImpact(followerGain: target, viewsGain: vGain)
            let t = tpl(id: "inactiveWakeup", type: .growth, icon: "arrow.up.heart.fill",
                titleKey: Tpl.Title.inactiveWakeup,
                reasonKey: Tpl.Reason.inactiveFollowers, reasonArgs: ["\(pct)%"],
                actionKeys: [Tpl.Action.dmTopFans, Tpl.Action.runGiveaway],
                actionArgsList: [["\(Int(wakeRatio * 100))"], []])
            return FilledTemplate(template: t, impact: impact, lowConfidence: false)
        })

    /// 15. 取关预警
    static let churnWarning = TemplateSpec(
        id: "churnWarning", type: .growth, icon: "person.crop.circle.badge.minus", baseScore: 80,
        minPosts: 0, minSnapshots: 2, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            let t = tpl(id: "churnWarning", type: .growth, icon: "person.crop.circle.badge.minus",
                titleKey: Tpl.Title.churnWarning,
                reasonKey: Tpl.Reason.churn, reasonArgs: ["\(features.context.churnDays7d)"],
                actionKeys: [Tpl.Action.engageTopFans, Tpl.Action.replyAll], actionArgsList: [[], []])
            guard features.context.churnDays7d >= 3 else {
                return FilledTemplate(template: t, impact: .zero, lowConfidence: true)
            }
            let lost = Int(abs(features.context.weekOverWeek.followersThisWeek).rounded())
            return FilledTemplate(template: t, impact: CardImpact(followerGain: lost, viewsGain: 0), lowConfidence: false)
        })

    /// 16. 取关高峰日
    static let churnPeakDay = TemplateSpec(
        id: "churnPeakDay", type: .growth, icon: "calendar.badge.exclamationmark", baseScore: 70,
        minPosts: 0, minSnapshots: 2, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            let day = dayName(features.context.churnPeakDay)
            let t = tpl(id: "churnPeakDay", type: .growth, icon: "calendar.badge.exclamationmark",
                titleKey: Tpl.Title.churnPeakDay, titleArgs: [day],
                reasonKey: Tpl.Reason.churnDay, reasonArgs: [pct(features.context.churnPeakShare), day],
                actionKeys: [Tpl.Action.postAtDay], actionArgsList: [[day]])
            let strong = features.context.churnDays7d >= 2 && features.context.churnPeakShare >= 0.5
            return FilledTemplate(template: t, impact: .zero, lowConfidence: !strong)
        })

    /// 17. 转化率提升
    static let conversionBoost = TemplateSpec(
        id: "conversionBoost", type: .growth, icon: "arrow.triangle.2.circlepath.circle.fill", baseScore: 60,
        minPosts: 0, minSnapshots: 2, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            let fpv = features.impact.rates.followerPerView
            let t = tpl(id: "conversionBoost", type: .growth, icon: "arrow.triangle.2.circlepath.circle.fill",
                titleKey: Tpl.Title.conversionBoost,
                reasonKey: Tpl.Reason.conversion, reasonArgs: [String(format: "%.3f", fpv * 100)],
                actionKeys: [Tpl.Action.askComments, Tpl.Action.crossPromote], actionArgsList: [[], []])
            guard fpv > 0, fpv < 0.0005, features.context.weekOverWeek.viewsThisWeek > 0 else {
                return FilledTemplate(template: t, impact: .zero, lowConfidence: true)
            }
            let gain = Int((features.context.weekOverWeek.viewsThisWeek * fpv * 0.2).rounded())
            return FilledTemplate(template: t, impact: CardImpact(followerGain: gain, viewsGain: 0), lowConfidence: false)
        })

    /// 18. 粉丝质量提示
    static let followerQuality = TemplateSpec(
        id: "followerQuality", type: .growth, icon: "person.2.slash.fill", baseScore: 55,
        minPosts: 0, minSnapshots: 1, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            let health = features.followerHealth
            guard health.totalFollowers > 0 else { return nil }
            let pctVal = Int((health.activeRatio * 100).rounded())
            let t = tpl(id: "followerQuality", type: .growth, icon: "person.2.slash.fill",
                titleKey: Tpl.Title.followerQuality,
                reasonKey: Tpl.Reason.lowQuality, reasonArgs: ["\(pctVal)%"],
                actionKeys: [Tpl.Action.engageTopFans], actionArgsList: [["10"]])
            return FilledTemplate(template: t, impact: .zero, lowConfidence: health.activeRatio >= 0.15)
        })

    /// 19. 高价值粉丝互动
    static let topFansEngage = TemplateSpec(
        id: "topFansEngage", type: .growth, icon: "star.fill", baseScore: 45,
        minPosts: 0, minSnapshots: 1, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            let health = features.followerHealth
            guard health.totalFollowers > 0 else { return nil }
            let t = tpl(id: "topFansEngage", type: .growth, icon: "star.fill",
                titleKey: Tpl.Title.topFansEngage,
                reasonKey: Tpl.Reason.topFans, reasonArgs: [ActionCard.formatCount(health.activeFollowers)],
                actionKeys: [Tpl.Action.engageTopFans, Tpl.Action.dmTopFans], actionArgsList: [["10"], ["20"]])
            return FilledTemplate(template: t, impact: .zero, lowConfidence: health.activeFollowers < 100)
        })

    /// 20. 周目标设定
    static let growthTarget = TemplateSpec(
        id: "growthTarget", type: .growth, icon: "target", baseScore: 35,
        minPosts: 0, minSnapshots: 2, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            let weekly = Int((features.followerHealth.followerGrowth30d / 4).rounded())
            let t = tpl(id: "growthTarget", type: .growth, icon: "target",
                titleKey: Tpl.Title.growthTarget,
                reasonKey: Tpl.Reason.growthTarget, reasonArgs: [ActionCard.formatCount(weekly)],
                actionKeys: [Tpl.Action.boost, Tpl.Action.scheduleMore],
                actionArgsList: [["\(recommendedExtraPosts(features))", "Reel"], ["\(recommendedWeeklyTarget(features))"]])
            let strong = features.followerHealth.followerGrowth30d > 0
            return FilledTemplate(template: t, impact: .zero, lowConfidence: !strong)
        })

    // ───────────────────────── Engagement ─────────────────────────

    /// 21. 互动率下滑预警
    static let engagementDecline = TemplateSpec(
        id: "engagementDecline", type: .engagement, icon: "heart.slash.fill", baseScore: 80,
        minPosts: 0, minSnapshots: 1, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            let trend = features.context.engagementTrend
            guard trend.firstHalf > 0 || trend.lastHalf > 0 else { return nil }
            let t = tpl(id: "engagementDecline", type: .engagement, icon: "heart.slash.fill",
                titleKey: Tpl.Title.engagementDecline,
                reasonKey: Tpl.Reason.engagementDecline, reasonArgs: [pct(trend.changeRatio)],
                actionKeys: [Tpl.Action.askComments, Tpl.Action.replyAll], actionArgsList: [[], []])
            let strong = trend.direction == .down && trend.lastHalf > 0
            return FilledTemplate(template: t, impact: .zero, lowConfidence: !strong)
        })

    /// 22. 回复评论
    static let replyComments = TemplateSpec(
        id: "replyComments", type: .engagement, icon: "bubble.left.fill", baseScore: 65,
        minPosts: 0, minSnapshots: 2, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            let wow = features.context.weekOverWeek
            let t = tpl(id: "replyComments", type: .engagement, icon: "bubble.left.fill",
                titleKey: Tpl.Title.replyComments,
                reasonKey: Tpl.Reason.reply, reasonArgs: ["\(Int(wow.engagementThisWeek.rounded()))"],
                actionKeys: [Tpl.Action.replyAll], actionArgsList: [["\(Int(wow.engagementThisWeek.rounded()))"]])
            let strong = wow.engagementThisWeek > 0 && wow.engagementLastWeek > 0
                && wow.engagementThisWeek >= wow.engagementLastWeek * 1.5
            return FilledTemplate(template: t, impact: .zero, lowConfidence: !strong)
        })

    /// 23. Q&A 互动
    static let qAndA = TemplateSpec(
        id: "qAndA", type: .engagement, icon: "questionmark.bubble.fill", baseScore: 60,
        minPosts: 0, minSnapshots: 2, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            let wow = features.context.weekOverWeek
            let t = tpl(id: "qAndA", type: .engagement, icon: "questionmark.bubble.fill",
                titleKey: Tpl.Title.qAndA,
                reasonKey: Tpl.Reason.qna, reasonArgs: ["\(Int(wow.engagementThisWeek.rounded()))"],
                actionKeys: [Tpl.Action.qna])
            let strong = wow.engagementThisWeek > 0 && wow.engagementLastWeek > 0
                && wow.engagementThisWeek >= wow.engagementLastWeek * 2
            return FilledTemplate(template: t, impact: .zero, lowConfidence: !strong)
        })

    /// 24. 分享率提升
    static let shareRateLow = TemplateSpec(
        id: "shareRateLow", type: .engagement, icon: "arrowshape.turn.up.right.fill", baseScore: 45,
        minPosts: 0, minSnapshots: 1, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { _, _ in
            FilledTemplate(
                template: tpl(id: "shareRateLow", type: .engagement, icon: "arrowshape.turn.up.right.fill",
                    titleKey: Tpl.Title.shareRateLow,
                    reasonKey: Tpl.Reason.shareRate,
                    actionKeys: [Tpl.Action.encourageShare]),
                impact: .zero, lowConfidence: false)
        })

    /// 25. 爆款承接
    static let viralFollowUp = TemplateSpec(
        id: "viralFollowUp", type: .engagement, icon: "bolt.fill", baseScore: 55,
        minPosts: 1, minSnapshots: 0, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            let avg = overallAvgEngagement(features)
            guard let type = features.context.topPostType else { return nil }
            let name = "\(type)".capitalized
            let t = tpl(id: "viralFollowUp", type: .engagement, icon: "bolt.fill",
                titleKey: Tpl.Title.viralFollowUp, titleArgs: [name],
                reasonKey: Tpl.Reason.viralFollowUp,
                actionKeys: [Tpl.Action.followUp], actionArgsList: [[name]])
            let strong = avg > 0 && features.context.topPostEngagement >= avg * 3
            return FilledTemplate(template: t, impact: .zero, lowConfidence: !strong)
        })

    // ───────────────────────── Reach ─────────────────────────

    /// 26. 触达下滑预警
    static let reachDecline = TemplateSpec(
        id: "reachDecline", type: .reach, icon: "antenna.radiowaves.left.and.right.slash", baseScore: 85,
        minPosts: 0, minSnapshots: 1, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            let trend = features.context.reachTrend
            guard trend.firstHalf > 0 || trend.lastHalf > 0 else { return nil }
            let t = tpl(id: "reachDecline", type: .reach, icon: "antenna.radiowaves.left.and.right.slash",
                titleKey: Tpl.Title.reachDecline,
                reasonKey: Tpl.Reason.reachDecline, reasonArgs: [pct(trend.changeRatio)],
                actionKeys: [Tpl.Action.checkReach, Tpl.Action.boost],
                actionArgsList: [[], ["\(recommendedExtraPosts(features))", "Reel"]])
            let strong = trend.direction == .down && trend.lastHalf > 0
            if strong {
                let gain = Int((trend.lastHalf * 0.1 * features.impact.rates.followerPerView).rounded())
                return FilledTemplate(template: t, impact: CardImpact(followerGain: gain, viewsGain: 0), lowConfidence: false)
            }
            return FilledTemplate(template: t, impact: .zero, lowConfidence: true)
        })

    /// 27. 主页浏览提升
    static let profileViewsBoost = TemplateSpec(
        id: "profileViewsBoost", type: .reach, icon: "person.crop.rectangle.fill", baseScore: 65,
        minPosts: 0, minSnapshots: 1, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            let trend = features.context.profileViewsTrend
            guard trend.firstHalf > 0 || trend.lastHalf > 0 else { return nil }
            let t = tpl(id: "profileViewsBoost", type: .reach, icon: "person.crop.rectangle.fill",
                titleKey: Tpl.Title.profileViewsBoost,
                reasonKey: Tpl.Reason.profileViews, reasonArgs: [pct(trend.changeRatio)],
                actionKeys: [Tpl.Action.optimizeProfile])
            let strong = trend.direction == .down || (trend.lastHalf == 0 && trend.firstHalf > 0)
            return FilledTemplate(template: t, impact: .zero, lowConfidence: !strong)
        })

    /// 28. 高触达低互动诊断
    static let reachWasted = TemplateSpec(
        id: "reachWasted", type: .reach, icon: "exclamationmark.arrow.triangle.2.circlepath", baseScore: 70,
        minPosts: 0, minSnapshots: 1, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            let reach = features.context.reachTrend
            let eng = features.context.engagementTrend
            guard reach.firstHalf > 0 || eng.firstHalf > 0 else { return nil }
            let t = tpl(id: "reachWasted", type: .reach, icon: "exclamationmark.arrow.triangle.2.circlepath",
                titleKey: Tpl.Title.reachWasted,
                reasonKey: Tpl.Reason.reachWasted, reasonArgs: [pct(eng.changeRatio)],
                actionKeys: [Tpl.Action.checkReach, Tpl.Action.tryNewFormat], actionArgsList: [[], ["Reel"]])
            let strong = reach.direction == .up && eng.direction == .down
            return FilledTemplate(template: t, impact: .zero, lowConfidence: !strong)
        })

    /// 29. 稳定发布节奏
    static let stablePublishing = TemplateSpec(
        id: "stablePublishing", type: .reach, icon: "waveform.path.ecg", baseScore: 45,
        minPosts: 4, minSnapshots: 0, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            let wow = features.context.weekOverWeek
            let t = tpl(id: "stablePublishing", type: .reach, icon: "waveform.path.ecg",
                titleKey: Tpl.Title.stablePublishing,
                reasonKey: Tpl.Reason.unstablePublishing, reasonArgs: ["\(abs(wow.postsThisWeek - wow.postsLastWeek))"],
                actionKeys: [Tpl.Action.stabilize])
            let strong = wow.postsLastWeek > 0 && abs(wow.postsThisWeek - wow.postsLastWeek) >= 3
            return FilledTemplate(template: t, impact: .zero, lowConfidence: !strong)
        })

    // ───────────────────────── Health ─────────────────────────

    /// 30. 关注比异常
    static let followingRatioHigh = TemplateSpec(
        id: "followingRatioHigh", type: .health, icon: "person.fill.checkmark", baseScore: 50,
        minPosts: 0, minSnapshots: 1, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            let health = features.followerHealth
            guard health.totalFollowers > 0 else { return nil }
            let pctVal = Int((Double(features.context.followingCount) / Double(health.totalFollowers) * 100).rounded())
            let t = tpl(id: "followingRatioHigh", type: .health, icon: "person.fill.checkmark",
                titleKey: Tpl.Title.followingRatioHigh,
                reasonKey: Tpl.Reason.followingRatio, reasonArgs: ["\(pctVal)%"],
                actionKeys: [Tpl.Action.unfollowClean])
            let strong = Double(features.context.followingCount) / Double(health.totalFollowers) > 0.8
            return FilledTemplate(template: t, impact: .zero, lowConfidence: !strong)
        })

    /// 31. 草稿堆积
    static let draftBacklog = TemplateSpec(
        id: "draftBacklog", type: .health, icon: "doc.text.fill", baseScore: 55,
        minPosts: 0, minSnapshots: 0, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            guard features.context.draftCount > 0 else { return nil }
            let t = tpl(id: "draftBacklog", type: .health, icon: "doc.text.fill",
                titleKey: Tpl.Title.draftBacklog,
                reasonKey: Tpl.Reason.drafts, reasonArgs: ["\(features.context.draftCount)"],
                actionKeys: [Tpl.Action.publishDrafts], actionArgsList: [["\(features.context.draftCount)"]])
            return FilledTemplate(template: t, impact: .zero, lowConfidence: features.context.draftCount < 3)
        })

    /// 32. 断更预警
    static let postingGap = TemplateSpec(
        id: "postingGap", type: .health, icon: "exclamationmark.octagon.fill", baseScore: 85,
        minPosts: 1, minSnapshots: 0, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            let t = tpl(id: "postingGap", type: .health, icon: "exclamationmark.octagon.fill",
                titleKey: Tpl.Title.postingGap,
                reasonKey: Tpl.Reason.postingGap, reasonArgs: ["\(features.context.daysSinceLastPost)"],
                actionKeys: [Tpl.Action.postNow])
            return FilledTemplate(template: t, impact: .zero, lowConfidence: features.context.daysSinceLastPost <= 7)
        })

    /// 33. 数据覆盖不足
    static let dataCoverage = TemplateSpec(
        id: "dataCoverage", type: .health, icon: "chart.bar.doc.horizontal.fill", baseScore: 40,
        minPosts: 0, minSnapshots: 0, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            guard features.context.snapshotCount < 30 else { return nil }
            return FilledTemplate(
                template: tpl(id: "dataCoverage", type: .health, icon: "chart.bar.doc.horizontal.fill",
                    titleKey: Tpl.Title.dataCoverage,
                    reasonKey: Tpl.Reason.dataCoverage, reasonArgs: ["\(features.context.snapshotCount)"],
                    actionKeys: [Tpl.Action.syncMore]),
                impact: .zero, lowConfidence: false)
        })

    // ───────────────────────── Ops ─────────────────────────

    /// 34. 旧爆款重发
    static let reuseViral = TemplateSpec(
        id: "reuseViral", type: .ops, icon: "arrow.counterclockwise.circle.fill", baseScore: 40,
        minPosts: 1, minSnapshots: 0, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            let avg = overallAvgEngagement(features)
            guard let type = features.context.topPostType else { return nil }
            let name = "\(type)".capitalized
            let multiplier = avg > 0 ? features.context.topPostEngagement / avg : 0
            let t = tpl(id: "reuseViral", type: .ops, icon: "arrow.counterclockwise.circle.fill",
                titleKey: Tpl.Title.reuseViral, titleArgs: [name],
                reasonKey: Tpl.Reason.viral, reasonArgs: [name, String(format: "%.1f", multiplier)],
                actionKeys: [Tpl.Action.reuseViral])
            let strong = avg > 0 && features.context.topPostEngagement >= avg * 3
                && features.context.daysSinceLastPost > 14
            return FilledTemplate(template: t, impact: .zero, lowConfidence: !strong)
        })

    /// 35. 月度内容日历
    static let monthlyPlan = TemplateSpec(
        id: "monthlyPlan", type: .ops, icon: "calendar", baseScore: 30,
        minPosts: 4, minSnapshots: 0, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            let total = totalPosts(features)
            let t = tpl(id: "monthlyPlan", type: .ops, icon: "calendar",
                titleKey: Tpl.Title.monthlyPlan,
                reasonKey: Tpl.Reason.monthlyPlan, reasonArgs: ["\(total)"],
                actionKeys: [Tpl.Action.monthlyPlan])
            return FilledTemplate(template: t, impact: .zero, lowConfidence: total < 10)
        })

    /// 36. 系列化内容
    static let seriesContent = TemplateSpec(
        id: "seriesContent", type: .ops, icon: "square.stack.3d.up.fill", baseScore: 30,
        minPosts: 4, minSnapshots: 0, applicablePhases: nil, direction: .neutral,
        targetValue: nil, currentValue: nil,
        build: { features, _ in
            let t = tpl(id: "seriesContent", type: .ops, icon: "square.stack.3d.up.fill",
                titleKey: Tpl.Title.seriesContent,
                reasonKey: Tpl.Reason.seriesContent,
                actionKeys: [Tpl.Action.monthlyPlan])
            return FilledTemplate(template: t, impact: .zero, lowConfidence: features.context.postsLast7d < 3)
        })
}

// MARK: - 统一流水线

/// 模板引擎入口 — 门槛过滤 → 语义校验 → 候选
struct TemplateEngine: Sendable {

    /// 全部触发的模板候选
    static func candidates(features: GrowthFeatures, scores: GrowthScores) -> [TemplateCandidate] {
        let posts = totalPosts(features)
        let snapshots = features.context.snapshotCount
        let phase = features.context.phase

        return TemplateRegistry.all.compactMap { spec in
            // ① 数据门槛
            guard posts >= spec.minPosts, snapshots >= spec.minSnapshots else { return nil }
            // ② 阶段兼容
            if let phases = spec.applicablePhases, !phases.contains(phase) { return nil }
            // ③ 数字填充
            guard let filled = spec.build(features, scores) else { return nil }
            // ④ 语义校验
            guard semanticValid(spec, filled, features) else { return nil }
            // ⑤ 机会分（强档 = 有收益或高置信；弱档 = 估算减半）
            let strong = !filled.lowConfidence
            let score = strong
                ? score(base: spec.baseScore, gain: filled.impact.followerGain)
                : spec.baseScore / 2
            return TemplateCandidate(
                template: filled.template, score: score,
                impact: filled.impact, lowConfidence: filled.lowConfidence)
        }
    }

    // MARK: - 语义校验（数字与模板契约的适配保证）

    /// 校验：收益非负 + 方向一致性（increase → 目标 > 当前；decrease → 目标 < 当前）
    static func semanticValid(_ spec: TemplateSpec, _ filled: FilledTemplate, _ features: GrowthFeatures) -> Bool {
        // 收益非负
        guard filled.impact.followerGain >= 0, filled.impact.viewsGain >= 0 else { return false }
        // 方向一致性
        guard spec.direction != .neutral,
              let target = spec.targetValue?(features),
              let current = spec.currentValue?(features) else { return true }
        switch spec.direction {
        case .increase: return target > current
        case .decrease: return target < current
        case .neutral:  return true
        }
    }

    // MARK: - Scoring Helpers

    /// 机会分：基准 + 收益加成（粉丝收益封顶 +30）
    static func score(base: Int, gain: Int) -> Int {
        base + min(30, max(0, gain))
    }
}

// MARK: - Shared Helpers

/// 帖子总数
private func totalPosts(_ features: GrowthFeatures) -> Int {
    features.contentPerformance.values.map(\.totalPosts).reduce(0, +)
}

/// 渲染模板构造（统一入口，保证字段完整）
private func tpl(id: String, type: CardType, icon: String,
                 titleKey: String, titleArgs: [String] = [],
                 reasonKey: String, reasonArgs: [String] = [],
                 actionKeys: [String], actionArgsList: [[String]] = []) -> DecisionTemplate {
    DecisionTemplate(
        id: id, type: type, icon: icon,
        titleKey: titleKey, titleArgs: titleArgs,
        reasonKey: reasonKey, reasonArgs: reasonArgs,
        actionKeys: actionKeys, actionArgsList: actionArgsList)
}

/// 平均每帖收益（top 类型）
private func perPostGain(_ type: ContentType, features: GrowthFeatures) -> (fans: Double, views: Double) {
    (features.impact.perPostFollowerGain[type] ?? 0, features.impact.perPostViewsGain[type] ?? 0)
}

/// 整体平均互动（likes + comments per post）
private func overallAvgEngagement(_ features: GrowthFeatures) -> Double {
    let values = features.contentPerformance.values.map(\.avgEngagement)
    return values.reduce(0, +) / Double(max(1, values.count))
}

/// 建议加发条数（数据驱动）：目标周频率 = 近 30 天周均 + 1，减去本周已发数，clamp 1...3
private func recommendedExtraPosts(_ features: GrowthFeatures) -> Int {
    let target = features.context.avgWeeklyPosts + 1
    let extra = Int(target.rounded()) - features.context.postsLast7d
    return clamp(extra, 1, 3)
}

/// 推荐周发帖目标（数据驱动）：近 30 天周均 + 1
private func recommendedWeeklyTarget(_ features: GrowthFeatures) -> Double {
    max(1, features.context.avgWeeklyPosts.rounded() + 1)
}

/// 唤醒不活跃粉丝比例（数据驱动）：活跃比越高唤醒潜力越大，clamp 5%...20%
private func wakeupRatio(_ features: GrowthFeatures) -> Double {
    let ratio = features.followerHealth.activeRatio * 0.5
    return Swift.min(0.20, Swift.max(0.05, ratio))
}

private func dayName(_ day: Int) -> String {
    dayNames[clamp(day - 1, 0, 6)]
}

/// 百分比字符串（保留符号，四舍五入）：-0.25 → "-25%"
private func pct(_ ratio: Double) -> String {
    "\(Int((ratio * 100).rounded()))%"
}

private let dayNames = [
    loc(L10n.Premium.daySun), loc(L10n.Premium.dayMon), loc(L10n.Premium.dayTue),
    loc(L10n.Premium.dayWed), loc(L10n.Premium.dayThu), loc(L10n.Premium.dayFri),
    loc(L10n.Premium.daySat)
]

private func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int { Swift.min(hi, Swift.max(lo, v)) }
