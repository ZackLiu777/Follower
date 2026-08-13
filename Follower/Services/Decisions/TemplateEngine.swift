//
//  TemplateEngine.swift
//  Follower
//
//  决策模板引擎 — 41 个 P0 模板的注册与触发（双档生成）。
//
//  双档设计（建议数据库化：有基础数据即生成，信号强度决定排序与置信度）：
//  - 强信号：机会分高 + 量化收益 → 主列表
//  - 弱信号（有基础数据但信号不足）：机会分低 + 无收益 + lowConfidence
//    （UI 显示「估算」标签）→ 折叠区
//  - 无基础数据（如 0 快照 / 0 帖子）：不生成（避免凑数）
//
//  机会分 = 领域基准分 + 收益加成（followerGain 封顶 30）。
//  触发阈值集中在此文件，便于评审与测试。
//

import Foundation

// MARK: - TemplateEngine

/// 模板引擎 — 输入特征，输出全部生成的候选建议（双档）
struct TemplateEngine: Sendable {

    // MARK: - Main Entry

    /// 全部生成的模板候选（强信号 + 弱信号降级版）
    static func candidates(features: GrowthFeatures, scores: GrowthScores) -> [TemplateCandidate] {
        var result: [TemplateCandidate] = []
        let builders: [((GrowthFeatures, GrowthScores) -> TemplateCandidate?)] = [
            // content 12
            boostTopType, rescueDecliningType, replicateViral, lowEngagementDiagnosis,
            diversifyTypes, carouselForLongContent, increaseFrequency, reduceFrequency,
            balanceWeeklyCadence, testSecondBestType, typeTrendWarning, guideComments,
            // timing 5
            bestHour, bestDay, secondBestHour, avoidWorstHours, weekdayVsWeekend,
            // growth 8
            growthSlowdown, inactiveWakeup, churnWarning, churnPeakDay,
            conversionBoost, followerQuality, topFansEngage, growthTarget,
            // engagement 5
            engagementDecline, replyComments, qAndA, shareRateLow, viralFollowUp,
            // reach 4
            reachDecline, profileViewsBoost, reachWasted, stablePublishing,
            // health 5
            followingRatioHigh, draftBacklog, postingGap, dataCoverage,
            // ops 3
            reuseViral, monthlyPlan, seriesContent,
        ]
        for build in builders {
            if let candidate = build(features, scores) {
                result.append(candidate)
            }
        }
        return result
    }

    // MARK: - Scoring Helpers

    /// 机会分：基准 + 收益加成（粉丝收益封顶 +30）
    private static func score(base: Int, gain: Int) -> Int {
        base + min(30, max(0, gain))
    }

    /// 帖子总数
    private static func totalPosts(_ features: GrowthFeatures) -> Int {
        features.contentPerformance.values.map(\.totalPosts).reduce(0, +)
    }

    /// 快照天数
    private static func snapshotCount(_ features: GrowthFeatures) -> Int {
        features.context.snapshotCount
    }

    /// 平均每帖收益（top 类型）
    private static func perPostGain(_ type: ContentType, features: GrowthFeatures) -> (fans: Double, views: Double) {
        (features.impact.perPostFollowerGain[type] ?? 0, features.impact.perPostViewsGain[type] ?? 0)
    }

    /// 整体平均互动（likes + comments per post）
    private static func overallAvgEngagement(_ features: GrowthFeatures) -> Double {
        let values = features.contentPerformance.values.map(\.avgEngagement)
        return values.reduce(0, +) / Double(max(1, values.count))
    }

    private static func dayName(_ day: Int) -> String {
        dayNames[clamp(day - 1, 0, 6)]
    }

    /// 弱信号候选（低分 + 无收益 + 估算标签）
    private static func weak(_ template: DecisionTemplate, score: Int) -> TemplateCandidate {
        TemplateCandidate(template: template, score: score, impact: .zero, lowConfidence: true)
    }

    /// 建议加发条数（数据驱动）：目标周频率 = 近 30 天周均 + 1，减去本周已发数，clamp 1...3
    private static func recommendedExtraPosts(_ features: GrowthFeatures) -> Int {
        let target = features.context.avgWeeklyPosts + 1
        let extra = Int(target.rounded()) - features.context.postsLast7d
        return clamp(extra, 1, 3)
    }

    /// 推荐周发帖目标（数据驱动）：近 30 天周均 + 1
    private static func recommendedWeeklyTarget(_ features: GrowthFeatures) -> Int {
        max(1, Int(features.context.avgWeeklyPosts.rounded()) + 1)
    }

    /// 唤醒不活跃粉丝比例（数据驱动）：活跃比越高唤醒潜力越大，clamp 5%...20%
    private static func wakeupRatio(_ features: GrowthFeatures) -> Double {
        let ratio = features.followerHealth.activeRatio * 0.5
        return Swift.min(0.20, Swift.max(0.05, ratio))
    }

    // MARK: - Content (12)

    /// 1. 加码最强内容类型 — 最高分类型按数据推荐条数加发
    static func boostTopType(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        guard let top = scores.contentScores.first, top.1 > 0.01 else { return nil }
        let (fans, views) = perPostGain(top.0, features: features)
        let name = "\(top.0)".capitalized
        let extra = recommendedExtraPosts(features)
        let t = DecisionTemplate(
            id: "boostTopType", type: .content, icon: "flame.fill",
            titleKey: Tpl.Title.boostTopType, titleArgs: [name],
            reasonKey: Tpl.Reason.perPostGain, reasonArgs: [name, ActionCard.formatCount(Int(fans.rounded()))],
            actionKeys: [Tpl.Action.boost], actionArgsList: [["\(extra)", name]])
        guard fans > 0 else {
            // 弱信号：有类型无转化率（数据不足）→ 换数据积累原因，不显示死数字
            let tLow = DecisionTemplate(
                id: "boostTopType", type: .content, icon: "flame.fill",
                titleKey: Tpl.Title.boostTopType, titleArgs: [name],
                reasonKey: Tpl.Reason.insufficientData, reasonArgs: [name],
                actionKeys: [Tpl.Action.boost], actionArgsList: [["\(extra)", name]])
            return weak(tLow, score: 15)
        }
        let impact = CardImpact(followerGain: Int((Double(extra) * fans).rounded()),
            viewsGain: Int((Double(extra) * views).rounded()))
        return TemplateCandidate(template: t, score: score(base: 100, gain: impact.followerGain), impact: impact)
    }

    /// 2. 挽救下滑类型 — top 类型互动明显下滑
    static func rescueDecliningType(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        guard let top = scores.contentScores.first, top.1 > 0.01 else { return nil }
        let name = "\(top.0)".capitalized
        let stats = features.contentPerformance[top.0]
        let declinePct = pct(stats?.growthRate ?? 0)
        let t = DecisionTemplate(
            id: "rescueDecliningType", type: .content, icon: "arrow.uturn.down.circle.fill",
            titleKey: Tpl.Title.rescueDecliningType, titleArgs: [name],
            reasonKey: Tpl.Reason.typeDeclining, reasonArgs: [name, declinePct],
            actionKeys: [Tpl.Action.tryNewFormat, Tpl.Action.replyAll], actionArgsList: [[name], []])
        guard let stats, stats.growthRate < -0.2 else {
            return weak(t, score: 15)
        }
        return TemplateCandidate(template: t, score: 85, impact: .zero)
    }

    /// 3. 复制爆款 — 最高互动帖 ≥ 平均 3 倍
    static func replicateViral(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let avg = overallAvgEngagement(features)
        guard let type = features.context.topPostType else { return nil }
        let name = "\(type)".capitalized
        let multiplier = avg > 0 ? features.context.topPostEngagement / avg : 0
        let t = DecisionTemplate(
            id: "replicateViral", type: .content, icon: "star.circle.fill",
            titleKey: Tpl.Title.replicateViral, titleArgs: [name],
            reasonKey: Tpl.Reason.viral, reasonArgs: [name, String(format: "%.1f", multiplier)],
            actionKeys: [Tpl.Action.boost], actionArgsList: [["\(recommendedExtraPosts(features))", name]])
        guard avg > 0, features.context.topPostEngagement >= avg * 3 else {
            return weak(t, score: 18)
        }
        let (fans, views) = perPostGain(type, features: features)
        let impact = CardImpact(followerGain: Int((Double(recommendedExtraPosts(features)) * fans).rounded()),
            viewsGain: Int((Double(recommendedExtraPosts(features)) * views).rounded()))
        return TemplateCandidate(template: t, score: score(base: 95, gain: impact.followerGain), impact: impact)
    }

    /// 4. 低互动帖子诊断 — 低互动帖 ≥ 3 且占比 ≥ 30%
    static func lowEngagementDiagnosis(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let posts = totalPosts(features)
        guard posts >= 6 else { return nil }
        let t = DecisionTemplate(
            id: "lowEngagementDiagnosis", type: .content, icon: "magnifyingglass.circle.fill",
            titleKey: Tpl.Title.lowEngagementDiagnosis,
            reasonKey: Tpl.Reason.lowEngage, reasonArgs: ["\(features.context.lowEngagementPostCount)"],
            actionKeys: [Tpl.Action.analyzeLow])
        guard features.context.lowEngagementPostCount >= 3,
              Double(features.context.lowEngagementPostCount) / Double(posts) >= 0.3 else {
            return weak(t, score: 15)
        }
        return TemplateCandidate(template: t, score: 55, impact: .zero)
    }

    /// 5. 内容类型多样化 — 单一类型占比 > 70%
    static func diversifyTypes(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        guard let dominant = features.context.typeShare.max(by: { $0.value < $1.value }) else { return nil }
        let name = "\(dominant.key)".capitalized
        let pctVal = Int((dominant.value * 100).rounded())
        let t = DecisionTemplate(
            id: "diversifyTypes", type: .content, icon: "square.grid.2x2.fill",
            titleKey: Tpl.Title.diversifyTypes, titleArgs: [name, "\(pctVal)"],
            reasonKey: Tpl.Reason.dominant, reasonArgs: [name, "\(pctVal)"],
            actionKeys: [Tpl.Action.diversify], actionArgsList: [["\(pctVal)"]])
        guard dominant.value > 0.7 else {
            return weak(t, score: 12)
        }
        return TemplateCandidate(template: t, score: 50, impact: .zero)
    }

    /// 6. 长内容换格式 — Photo 占主导且互动显著低于其他类型
    static func carouselForLongContent(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        guard let photo = features.contentPerformance[.photo] else { return nil }
        let t = DecisionTemplate(
            id: "carouselForLongContent", type: .content, icon: "rectangle.on.rectangle.fill",
            titleKey: Tpl.Title.carouselForLongContent,
            reasonKey: Tpl.Reason.photoWeak, reasonArgs: ["Photo", "Reel/Video", "50"],
            actionKeys: [Tpl.Action.switchFormat])
        let others = features.contentPerformance.filter { $0.key != .photo }.values.map(\.avgEngagement).max() ?? 0
        guard (features.context.typeShare[.photo] ?? 0) > 0.5,
              others > 0, photo.avgEngagement < others * 0.5 else {
            return weak(t, score: 12)
        }
        return TemplateCandidate(template: t, score: 45, impact: .zero)
    }

    /// 7. 提升发帖频率 — 近 7 天 ≤ 1 帖且历史有发帖
    static func increaseFrequency(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        guard totalPosts(features) >= 4 else { return nil }
        let target = recommendedWeeklyTarget(features)
        let t = DecisionTemplate(
            id: "increaseFrequency", type: .content, icon: "plus.circle.fill",
            titleKey: Tpl.Title.increaseFrequency,
            reasonKey: Tpl.Reason.freqLow, reasonArgs: ["\(features.context.postsLast7d)"],
            actionKeys: [Tpl.Action.scheduleMore], actionArgsList: [["\(target)"]])
        guard features.context.postsLast7d <= 1 else {
            return weak(t, score: 14)
        }
        let top = scores.contentScores.first?.0 ?? .reel
        let (fans, views) = perPostGain(top, features: features)
        let impact = CardImpact(followerGain: Int((Double(target - features.context.postsLast7d) * fans).rounded()),
            viewsGain: Int((Double(target - features.context.postsLast7d) * views).rounded()))
        return TemplateCandidate(template: t, score: score(base: 70, gain: impact.followerGain), impact: impact)
    }

    /// 8. 降低发帖频率 — 近 7 天 ≥ 6 帖且互动趋势下滑
    static func reduceFrequency(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        guard totalPosts(features) >= 10 else { return nil }
        let target = max(3, Int(features.context.avgWeeklyPosts.rounded()) - 2)
        let t = DecisionTemplate(
            id: "reduceFrequency", type: .content, icon: "minus.circle.fill",
            titleKey: Tpl.Title.reduceFrequency,
            reasonKey: Tpl.Reason.freqHigh, reasonArgs: ["\(features.context.postsLast7d)"],
            actionKeys: [Tpl.Action.reduceTo], actionArgsList: [["\(target)"]])
        guard features.context.postsLast7d >= 6, features.context.engagementTrend.direction == .down else {
            return weak(t, score: 12)
        }
        return TemplateCandidate(template: t, score: 75, impact: .zero)
    }

    /// 9. 均匀发帖节奏 — 最长断更 ≥ 4 天（有发帖但断档）
    static func balanceWeeklyCadence(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        guard totalPosts(features) >= 4 else { return nil }
        let days = clamp(Int(features.context.avgWeeklyPosts.rounded()), 2, 5)
        let t = DecisionTemplate(
            id: "balanceWeeklyCadence", type: .content, icon: "calendar.badge.plus",
            titleKey: Tpl.Title.balanceWeeklyCadence,
            reasonKey: Tpl.Reason.cadence, reasonArgs: ["\(features.context.longestGapDays)"],
            actionKeys: [Tpl.Action.spreadCadence], actionArgsList: [["\(days)"]])
        guard features.context.longestGapDays >= 4 else {
            return weak(t, score: 13)
        }
        return TemplateCandidate(template: t, score: 60, impact: .zero)
    }

    /// 10. 测试次优类型 — 第二高分类型得分 > 0.4
    static func testSecondBestType(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        guard scores.contentScores.count >= 2 else { return nil }
        let name = "\(scores.contentScores[1].0)".capitalized
        let t = DecisionTemplate(
            id: "testSecondBestType", type: .content, icon: "flask.fill",
            titleKey: Tpl.Title.testSecondBestType, titleArgs: [name],
            reasonKey: Tpl.Reason.secondType, reasonArgs: [name],
            actionKeys: [Tpl.Action.testOne], actionArgsList: [[name]])
        guard scores.contentScores[1].1 > 0.4,
              let stats = features.contentPerformance[scores.contentScores[1].0],
              stats.avgEngagement > 0 else {
            return weak(t, score: 14)
        }
        return TemplateCandidate(template: t, score: 40, impact: .zero)
    }

    /// 11. 类型趋势预警 — 非 top 类型互动下滑 > 30%
    static func typeTrendWarning(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        guard let top = scores.contentScores.first?.0 else { return nil }
        let nonTop = features.contentPerformance
            .filter { $0.key != top && $0.value.totalPosts >= 3 }
            .sorted { $0.key.rawValue < $1.key.rawValue }
        guard let first = nonTop.first else {
            // 有帖子但无第二类型数据 → 弱信号提示关注趋势
            if totalPosts(features) >= 3 {
                let t = DecisionTemplate(
                    id: "typeTrendWarning", type: .content, icon: "chart.line.downtrend.xyaxis",
                    titleKey: Tpl.Title.typeTrendWarning, titleArgs: ["Content"],
                    reasonKey: Tpl.Reason.typeWarning, reasonArgs: ["Content", "0%"],
                    actionKeys: [Tpl.Action.pauseType], actionArgsList: [["Content"]])
                return weak(t, score: 13)
            }
            return nil
        }
        let name = "\(first.key)".capitalized
        let t = DecisionTemplate(
            id: "typeTrendWarning", type: .content, icon: "chart.line.downtrend.xyaxis",
            titleKey: Tpl.Title.typeTrendWarning, titleArgs: [name],
            reasonKey: Tpl.Reason.typeWarning, reasonArgs: [name, pct(first.value.growthRate)],
            actionKeys: [Tpl.Action.pauseType], actionArgsList: [[name]])
        guard first.value.growthRate < -0.3 else {
            return weak(t, score: 13)
        }
        return TemplateCandidate(template: t, score: 65, impact: .zero)
    }

    /// 12. 高赞低评论引导 — 有内容即生成（点赞转评论是通用最佳实践）
    static func guideComments(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        guard totalPosts(features) >= 4 else { return nil }
        let t = DecisionTemplate(
            id: "guideComments", type: .content, icon: "bubble.left.and.bubble.right.fill",
            titleKey: Tpl.Title.guideComments,
            reasonKey: Tpl.Reason.highLikesLowComments,
            actionKeys: [Tpl.Action.askComments])
        return TemplateCandidate(template: t, score: 55, impact: .zero)
    }

    // MARK: - Timing (5)

    /// 13. 最佳时段发帖 — 提升 > 5%
    static func bestHour(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let window = features.impact.hourUplift
        let hours = String(format: "%02d:00–%02d:00", window.startHour, window.endHour)
        let weeklyPosts = max(1, features.context.postsLast7d)
        let top = scores.contentScores.first?.0
        let (fans, views) = top.map { perPostGain($0, features: features) } ?? (0, 0)
        let t = DecisionTemplate(
            id: "bestHour", type: .timing, icon: "clock.fill",
            titleKey: Tpl.Title.bestHour, titleArgs: [hours],
            reasonKey: Tpl.Reason.hourUplift, reasonArgs: [hours, String(format: "%.1f", window.uplift)],
            actionKeys: [Tpl.Action.postAtHour], actionArgsList: [[hours]])
        guard window.uplift > 1.05 else {
            return weak(t, score: 20)
        }
        let g = window.uplift - 1
        let impact = CardImpact(followerGain: Int((Double(weeklyPosts) * g * fans).rounded()),
            viewsGain: Int((Double(weeklyPosts) * g * views).rounded()))
        return TemplateCandidate(template: t, score: score(base: 90, gain: impact.followerGain), impact: impact)
    }

    /// 14. 最佳日发帖 — 日提升 > 5%
    static func bestDay(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let day = dayName(features.impact.bestDay)
        let t = DecisionTemplate(
            id: "bestDay", type: .timing, icon: "calendar.fill",
            titleKey: Tpl.Title.bestDay, titleArgs: [day],
            reasonKey: Tpl.Reason.dayUplift, reasonArgs: [day, String(format: "%.1f", features.impact.dayUplift)],
            actionKeys: [Tpl.Action.postAtDay], actionArgsList: [[day]])
        guard features.impact.dayUplift > 1.05 else {
            return weak(t, score: 15)
        }
        return TemplateCandidate(template: t, score: 80, impact: .zero)
    }

    /// 15. 次佳时段补发 — 第二窗口提升 > 1.0
    static func secondBestHour(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let start = features.context.secondBestHour ?? 12
        let hours = String(format: "%02d:00", start)
        let t = DecisionTemplate(
            id: "secondBestHour", type: .timing, icon: "clock.badge.plus",
            titleKey: Tpl.Title.secondBestHour, titleArgs: [hours],
            reasonKey: Tpl.Reason.secondHour, reasonArgs: [hours, String(format: "%.0f", (features.context.secondBestUplift - 1) * 100)],
            actionKeys: [Tpl.Action.fillSecond], actionArgsList: [[hours]])
        guard features.context.secondBestHour != nil else {
            return weak(t, score: 12)
        }
        return TemplateCandidate(template: t, score: 55, impact: .zero)
    }

    /// 16. 避开最差时段
    static func avoidWorstHours(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let window = features.impact.hourUplift
        let hours = String(format: "%02d:00–%02d:00", window.worstStartHour, window.worstEndHour)
        let t = DecisionTemplate(
            id: "avoidWorstHours", type: .timing, icon: "hand.raised.fill",
            titleKey: Tpl.Title.avoidWorstHours, titleArgs: [hours],
            reasonKey: Tpl.Reason.avoidWorst, reasonArgs: [hours],
            actionKeys: [Tpl.Action.avoidWorst], actionArgsList: [[hours]])
        guard window.worstStartHour != window.startHour else {
            return weak(t, score: 12)
        }
        return TemplateCandidate(template: t, score: 45, impact: .zero)
    }

    /// 17. 周末 vs 工作日策略 — 差异 > 30%（本地化）
    static func weekdayVsWeekend(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let ratio = features.context.weekendVsWeekdayRatio
        let isWeekendBetter = ratio > 0
        let reasonKey = isWeekendBetter ? Tpl.Reason.weekendBetter : Tpl.Reason.weekdayBetter
        let actionKey = isWeekendBetter ? Tpl.Action.prioritizeWeekend : Tpl.Action.prioritizeWeekday
        let t = DecisionTemplate(
            id: "weekdayVsWeekend", type: .timing, icon: "sun.haze.fill",
            titleKey: Tpl.Title.weekdayVsWeekend,
            reasonKey: reasonKey, reasonArgs: [String(format: "%.0f", abs(ratio) * 100)],
            actionKeys: [actionKey])
        guard abs(ratio) > 0.3 else {
            return weak(t, score: 12)
        }
        return TemplateCandidate(template: t, score: 50, impact: .zero)
    }

    // MARK: - Growth (8)

    /// 18. 增长放缓回补 — 7 日速率 < 30 日速率一半（弱档也显示真实速率差）
    static func growthSlowdown(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let health = features.followerHealth
        guard snapshotCount(features) >= 2 else { return nil }
        let gap = Int(((health.followerGrowth30d - health.followerGrowth7d) / 4).rounded())
        let pctOfRate = health.followerGrowth30d > 0
            ? Int((100 * health.followerGrowth7d / health.followerGrowth30d).rounded()) : 100
        let t = DecisionTemplate(
            id: "growthSlowdown", type: .growth, icon: "chart.line.downtrend.xyaxis",
            titleKey: Tpl.Title.growthSlowdown,
            reasonKey: Tpl.Reason.growthSlowdown, reasonArgs: ["\(gap)", "\(pctOfRate)%"],
            actionKeys: [Tpl.Action.boost, Tpl.Action.engageTopFans], actionArgsList: [["\(recommendedExtraPosts(features))", "Reel"], []])
        guard health.followerGrowth30d > 0, health.followerGrowth7d < health.followerGrowth30d * 0.5 else {
            return weak(t, score: 15)
        }
        let vGain = features.impact.rates.followerPerView > 0
            ? Int((Double(gap) / features.impact.rates.followerPerView).rounded()) : 0
        let impact = CardImpact(followerGain: gap, viewsGain: vGain)
        return TemplateCandidate(template: t, score: score(base: 85, gain: gap), impact: impact)
    }

    /// 19. 不活跃粉丝唤醒（唤醒比例数据驱动：活跃比 × 0.5，clamp 5%...20%）
    static func inactiveWakeup(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let health = features.followerHealth
        guard health.inactiveFollowers > 0 else { return nil }
        let pct = Int((1.0 - health.activeRatio) * 100)
        let wakeRatio = wakeupRatio(features)
        let target = Int((Double(health.inactiveFollowers) * wakeRatio).rounded())
        let vGain = features.impact.rates.followerPerView > 0
            ? Int((Double(target) / features.impact.rates.followerPerView).rounded()) : 0
        let impact = CardImpact(followerGain: target, viewsGain: vGain)
        let t = DecisionTemplate(
            id: "inactiveWakeup", type: .growth, icon: "arrow.up.heart.fill",
            titleKey: Tpl.Title.inactiveWakeup,
            reasonKey: Tpl.Reason.inactiveFollowers, reasonArgs: ["\(pct)%"],
            actionKeys: [Tpl.Action.dmTopFans, Tpl.Action.runGiveaway], actionArgsList: [["\(Int(wakeRatio * 100))"], []])
        return TemplateCandidate(template: t, score: score(base: 75, gain: target), impact: impact)
    }

    /// 20. 取关预警 — 近 7 天 ≥ 3 天净取关
    static func churnWarning(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let t = DecisionTemplate(
            id: "churnWarning", type: .growth, icon: "person.crop.circle.badge.minus",
            titleKey: Tpl.Title.churnWarning,
            reasonKey: Tpl.Reason.churn, reasonArgs: ["\(features.context.churnDays7d)"],
            actionKeys: [Tpl.Action.engageTopFans, Tpl.Action.replyAll], actionArgsList: [[], []])
        guard snapshotCount(features) >= 2 else { return nil }
        guard features.context.churnDays7d >= 3 else {
            return weak(t, score: 15)
        }
        let lost = Int(abs(features.context.weekOverWeek.followersThisWeek).rounded())
        let impact = CardImpact(followerGain: lost, viewsGain: 0)
        return TemplateCandidate(template: t, score: score(base: 80, gain: lost), impact: impact)
    }

    /// 21. 取关高峰日 — 一半以上取关集中在某天
    static func churnPeakDay(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let day = dayName(features.context.churnPeakDay)
        let t = DecisionTemplate(
            id: "churnPeakDay", type: .growth, icon: "calendar.badge.exclamationmark",
            titleKey: Tpl.Title.churnPeakDay, titleArgs: [day],
            reasonKey: Tpl.Reason.churnDay, reasonArgs: [pct(features.context.churnPeakShare), day],
            actionKeys: [Tpl.Action.postAtDay], actionArgsList: [[day]])
        guard snapshotCount(features) >= 2 else { return nil }
        guard features.context.churnDays7d >= 2, features.context.churnPeakShare >= 0.5 else {
            return weak(t, score: 12)
        }
        return TemplateCandidate(template: t, score: 70, impact: .zero)
    }

    /// 22. 转化率提升 — 浏览→粉丝转化率过低
    static func conversionBoost(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let fpv = features.impact.rates.followerPerView
        let t = DecisionTemplate(
            id: "conversionBoost", type: .growth, icon: "arrow.triangle.2.circlepath.circle.fill",
            titleKey: Tpl.Title.conversionBoost,
            reasonKey: Tpl.Reason.conversion, reasonArgs: [String(format: "%.3f", fpv * 100)],
            actionKeys: [Tpl.Action.askComments, Tpl.Action.crossPromote], actionArgsList: [[], []])
        guard snapshotCount(features) >= 2 else { return nil }
        guard fpv > 0, fpv < 0.0005, features.context.weekOverWeek.viewsThisWeek > 0 else {
            return weak(t, score: 12)
        }
        let gain = Int((features.context.weekOverWeek.viewsThisWeek * fpv * 0.2).rounded())
        return TemplateCandidate(template: t, score: score(base: 60, gain: gain),
            impact: CardImpact(followerGain: gain, viewsGain: 0))
    }

    /// 23. 粉丝质量提示 — 活跃粉丝占比过低
    static func followerQuality(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let health = features.followerHealth
        guard health.totalFollowers > 0 else { return nil }
        let pctVal = Int((health.activeRatio * 100).rounded())
        let t = DecisionTemplate(
            id: "followerQuality", type: .growth, icon: "person.2.slash.fill",
            titleKey: Tpl.Title.followerQuality,
            reasonKey: Tpl.Reason.lowQuality, reasonArgs: ["\(pctVal)%"],
            actionKeys: [Tpl.Action.engageTopFans], actionArgsList: [["10"]])
        guard health.activeRatio < 0.15 else {
            return weak(t, score: 12)
        }
        return TemplateCandidate(template: t, score: 55, impact: .zero)
    }

    /// 24. 高价值粉丝互动 — 活跃粉丝充足
    static func topFansEngage(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let health = features.followerHealth
        guard health.totalFollowers > 0 else { return nil }
        let t = DecisionTemplate(
            id: "topFansEngage", type: .growth, icon: "star.fill",
            titleKey: Tpl.Title.topFansEngage,
            reasonKey: Tpl.Reason.topFans, reasonArgs: [ActionCard.formatCount(health.activeFollowers)],
            actionKeys: [Tpl.Action.engageTopFans, Tpl.Action.dmTopFans], actionArgsList: [["10"], ["20"]])
        guard health.activeFollowers >= 100 else {
            return weak(t, score: 10)
        }
        return TemplateCandidate(template: t, score: 45, impact: .zero)
    }

    /// 25. 周目标设定 — 有增长速率
    static func growthTarget(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let weekly = Int((features.followerHealth.followerGrowth30d / 4).rounded())
        let t = DecisionTemplate(
            id: "growthTarget", type: .growth, icon: "target",
            titleKey: Tpl.Title.growthTarget,
            reasonKey: Tpl.Reason.growthTarget, reasonArgs: [ActionCard.formatCount(weekly)],
            actionKeys: [Tpl.Action.boost, Tpl.Action.scheduleMore],
            actionArgsList: [["\(recommendedExtraPosts(features))", "Reel"], ["\(recommendedWeeklyTarget(features))"]])
        guard snapshotCount(features) >= 2 else { return nil }
        guard features.followerHealth.followerGrowth30d > 0 else {
            return weak(t, score: 10)
        }
        return TemplateCandidate(template: t, score: 35, impact: .zero)
    }

    // MARK: - Engagement (5)

    /// 26. 互动率下滑预警
    static func engagementDecline(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let trend = features.context.engagementTrend
        let t = DecisionTemplate(
            id: "engagementDecline", type: .engagement, icon: "heart.slash.fill",
            titleKey: Tpl.Title.engagementDecline,
            reasonKey: Tpl.Reason.engagementDecline, reasonArgs: [pct(trend.changeRatio)],
            actionKeys: [Tpl.Action.askComments, Tpl.Action.replyAll], actionArgsList: [[], []])
        guard trend.firstHalf > 0 || trend.lastHalf > 0 else { return nil }
        guard trend.direction == .down, trend.lastHalf > 0 else {
            return weak(t, score: 15)
        }
        return TemplateCandidate(template: t, score: 80, impact: .zero)
    }

    /// 27. 回复评论 — 本周互动量显著上升（评论多）
    static func replyComments(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let wow = features.context.weekOverWeek
        let t = DecisionTemplate(
            id: "replyComments", type: .engagement, icon: "bubble.left.fill",
            titleKey: Tpl.Title.replyComments,
            reasonKey: Tpl.Reason.reply, reasonArgs: ["\(Int(wow.engagementThisWeek.rounded()))"],
            actionKeys: [Tpl.Action.replyAll], actionArgsList: [["\(Int(wow.engagementThisWeek.rounded()))"]])
        guard snapshotCount(features) >= 2 else { return nil }
        guard wow.engagementThisWeek > 0, wow.engagementLastWeek > 0,
              wow.engagementThisWeek >= wow.engagementLastWeek * 1.5 else {
            return weak(t, score: 13)
        }
        return TemplateCandidate(template: t, score: 65, impact: .zero)
    }

    /// 28. Q&A 互动 — 互动量翻倍
    static func qAndA(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let wow = features.context.weekOverWeek
        let t = DecisionTemplate(
            id: "qAndA", type: .engagement, icon: "questionmark.bubble.fill",
            titleKey: Tpl.Title.qAndA,
            reasonKey: Tpl.Reason.qna, reasonArgs: ["\(Int(wow.engagementThisWeek.rounded()))"],
            actionKeys: [Tpl.Action.qna])
        guard snapshotCount(features) >= 2 else { return nil }
        guard wow.engagementThisWeek > 0, wow.engagementLastWeek > 0,
              wow.engagementThisWeek >= wow.engagementLastWeek * 2 else {
            return weak(t, score: 12)
        }
        return TemplateCandidate(template: t, score: 60, impact: .zero)
    }

    /// 29. 分享率提升 — 有数据即生成（分享引导是通用最佳实践）
    static func shareRateLow(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        guard snapshotCount(features) >= 1 else { return nil }
        let t = DecisionTemplate(
            id: "shareRateLow", type: .engagement, icon: "arrowshape.turn.up.right.fill",
            titleKey: Tpl.Title.shareRateLow,
            reasonKey: Tpl.Reason.shareRate,
            actionKeys: [Tpl.Action.encourageShare])
        return TemplateCandidate(template: t, score: 45, impact: .zero)
    }

    /// 30. 爆款承接 — 有爆款
    static func viralFollowUp(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let avg = overallAvgEngagement(features)
        guard let type = features.context.topPostType else { return nil }
        let t = DecisionTemplate(
            id: "viralFollowUp", type: .engagement, icon: "bolt.fill",
            titleKey: Tpl.Title.viralFollowUp, titleArgs: ["\(type)".capitalized],
            reasonKey: Tpl.Reason.viralFollowUp,
            actionKeys: [Tpl.Action.followUp], actionArgsList: [["\(type)".capitalized]])
        guard avg > 0, features.context.topPostEngagement >= avg * 3 else {
            return weak(t, score: 12)
        }
        return TemplateCandidate(template: t, score: 55, impact: .zero)
    }

    // MARK: - Reach (4)

    /// 31. 触达下滑预警
    static func reachDecline(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let trend = features.context.reachTrend
        let fpv = features.impact.rates.followerPerView
        let t = DecisionTemplate(
            id: "reachDecline", type: .reach, icon: "antenna.radiowaves.left.and.right.slash",
            titleKey: Tpl.Title.reachDecline,
            reasonKey: Tpl.Reason.reachDecline, reasonArgs: [pct(trend.changeRatio)],
            actionKeys: [Tpl.Action.checkReach, Tpl.Action.boost],
            actionArgsList: [[], ["\(recommendedExtraPosts(features))", "Reel"]])
        guard trend.firstHalf > 0 || trend.lastHalf > 0 else { return nil }
        guard trend.direction == .down, trend.lastHalf > 0 else {
            return weak(t, score: 15)
        }
        let gain = Int((trend.lastHalf * 0.1 * fpv).rounded())
        return TemplateCandidate(template: t, score: score(base: 85, gain: gain),
            impact: CardImpact(followerGain: gain, viewsGain: 0))
    }

    /// 32. 主页浏览提升 — 主页浏览趋势下滑
    static func profileViewsBoost(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let trend = features.context.profileViewsTrend
        let t = DecisionTemplate(
            id: "profileViewsBoost", type: .reach, icon: "person.crop.rectangle.fill",
            titleKey: Tpl.Title.profileViewsBoost,
            reasonKey: Tpl.Reason.profileViews, reasonArgs: [pct(trend.changeRatio)],
            actionKeys: [Tpl.Action.optimizeProfile])
        guard trend.firstHalf > 0 || trend.lastHalf > 0 else { return nil }
        guard trend.direction == .down || (trend.lastHalf == 0 && trend.firstHalf > 0) else {
            return weak(t, score: 12)
        }
        return TemplateCandidate(template: t, score: 65, impact: .zero)
    }

    /// 33. 高触达低互动诊断 — 触达上升但互动下滑
    static func reachWasted(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let reach = features.context.reachTrend
        let eng = features.context.engagementTrend
        let t = DecisionTemplate(
            id: "reachWasted", type: .reach, icon: "exclamationmark.arrow.triangle.2.circlepath",
            titleKey: Tpl.Title.reachWasted,
            reasonKey: Tpl.Reason.reachWasted, reasonArgs: [pct(eng.changeRatio)],
            actionKeys: [Tpl.Action.checkReach, Tpl.Action.tryNewFormat], actionArgsList: [[], ["Reel"]])
        guard reach.firstHalf > 0 || eng.firstHalf > 0 else { return nil }
        guard reach.direction == .up, eng.direction == .down else {
            return weak(t, score: 12)
        }
        return TemplateCandidate(template: t, score: 70, impact: .zero)
    }

    /// 34. 稳定发布节奏 — 周发帖数波动
    static func stablePublishing(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let wow = features.context.weekOverWeek
        let t = DecisionTemplate(
            id: "stablePublishing", type: .reach, icon: "waveform.path.ecg",
            titleKey: Tpl.Title.stablePublishing,
            reasonKey: Tpl.Reason.unstablePublishing, reasonArgs: ["\(abs(wow.postsThisWeek - wow.postsLastWeek))"],
            actionKeys: [Tpl.Action.stabilize])
        guard totalPosts(features) >= 4 else { return nil }
        guard wow.postsLastWeek > 0, abs(wow.postsThisWeek - wow.postsLastWeek) >= 3 else {
            return weak(t, score: 12)
        }
        return TemplateCandidate(template: t, score: 45, impact: .zero)
    }

    // MARK: - Health (5)

    /// 35. 关注比异常 — following/followers > 80%
    static func followingRatioHigh(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let health = features.followerHealth
        let pctVal = health.totalFollowers > 0
            ? Int((Double(features.context.followingCount) / Double(health.totalFollowers) * 100).rounded()) : 0
        let t = DecisionTemplate(
            id: "followingRatioHigh", type: .health, icon: "person.fill.checkmark",
            titleKey: Tpl.Title.followingRatioHigh,
            reasonKey: Tpl.Reason.followingRatio, reasonArgs: ["\(pctVal)%"],
            actionKeys: [Tpl.Action.unfollowClean])
        guard health.totalFollowers > 0 else { return nil }
        guard Double(features.context.followingCount) / Double(health.totalFollowers) > 0.8 else {
            return weak(t, score: 12)
        }
        return TemplateCandidate(template: t, score: 50, impact: .zero)
    }

    /// 36. 草稿堆积
    static func draftBacklog(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        guard features.context.draftCount > 0 else { return nil }
        let t = DecisionTemplate(
            id: "draftBacklog", type: .health, icon: "doc.text.fill",
            titleKey: Tpl.Title.draftBacklog,
            reasonKey: Tpl.Reason.drafts, reasonArgs: ["\(features.context.draftCount)"],
            actionKeys: [Tpl.Action.publishDrafts], actionArgsList: [["\(features.context.draftCount)"]])
        guard features.context.draftCount >= 3 else {
            return weak(t, score: 15)
        }
        return TemplateCandidate(template: t, score: 55, impact: .zero)
    }

    /// 37. 断更预警
    static func postingGap(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let t = DecisionTemplate(
            id: "postingGap", type: .health, icon: "exclamationmark.octagon.fill",
            titleKey: Tpl.Title.postingGap,
            reasonKey: Tpl.Reason.postingGap, reasonArgs: ["\(features.context.daysSinceLastPost)"],
            actionKeys: [Tpl.Action.postNow])
        guard totalPosts(features) >= 1 || snapshotCount(features) >= 2 else { return nil }
        guard features.context.daysSinceLastPost > 7 else {
            return weak(t, score: 15)
        }
        return TemplateCandidate(template: t, score: 85, impact: .zero)
    }

    /// 38. 数据覆盖不足 — 快照 < 30 天（引导类，数据积累期恒显示）
    static func dataCoverage(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        guard features.context.snapshotCount < 30 else { return nil }
        let t = DecisionTemplate(
            id: "dataCoverage", type: .health, icon: "chart.bar.doc.horizontal.fill",
            titleKey: Tpl.Title.dataCoverage,
            reasonKey: Tpl.Reason.dataCoverage, reasonArgs: ["\(features.context.snapshotCount)"],
            actionKeys: [Tpl.Action.syncMore])
        return TemplateCandidate(template: t, score: 40, impact: .zero)
    }

    // MARK: - Ops (3)

    /// 39. 旧爆款重发
    static func reuseViral(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let avg = overallAvgEngagement(features)
        guard let type = features.context.topPostType else { return nil }
        let name = "\(type)".capitalized
        let t = DecisionTemplate(
            id: "reuseViral", type: .ops, icon: "arrow.counterclockwise.circle.fill",
            titleKey: Tpl.Title.reuseViral, titleArgs: [name],
            reasonKey: Tpl.Reason.viral, reasonArgs: [name, "0.0"],
            actionKeys: [Tpl.Action.reuseViral])
        guard avg > 0, features.context.topPostEngagement >= avg * 3,
              features.context.daysSinceLastPost > 14 else {
            return weak(t, score: 10)
        }
        let t2 = DecisionTemplate(
            id: "reuseViral", type: .ops, icon: "arrow.counterclockwise.circle.fill",
            titleKey: Tpl.Title.reuseViral, titleArgs: [name],
            reasonKey: Tpl.Reason.viral, reasonArgs: [name, String(format: "%.1f", features.context.topPostEngagement / avg)],
            actionKeys: [Tpl.Action.reuseViral])
        return TemplateCandidate(template: t2, score: 40, impact: .zero)
    }

    /// 40. 月度内容日历
    static func monthlyPlan(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        let total = totalPosts(features)
        guard total >= 4 else { return nil }
        let t = DecisionTemplate(
            id: "monthlyPlan", type: .ops, icon: "calendar",
            titleKey: Tpl.Title.monthlyPlan,
            reasonKey: Tpl.Reason.monthlyPlan, reasonArgs: ["\(total)"],
            actionKeys: [Tpl.Action.monthlyPlan])
        guard total >= 10 else {
            return weak(t, score: 12)
        }
        return TemplateCandidate(template: t, score: 30, impact: .zero)
    }

    /// 41. 系列化内容
    static func seriesContent(_ features: GrowthFeatures, _ scores: GrowthScores) -> TemplateCandidate? {
        guard totalPosts(features) >= 4 else { return nil }
        let t = DecisionTemplate(
            id: "seriesContent", type: .ops, icon: "square.stack.3d.up.fill",
            titleKey: Tpl.Title.seriesContent,
            reasonKey: Tpl.Reason.seriesContent,
            actionKeys: [Tpl.Action.monthlyPlan])
        guard features.context.postsLast7d >= 3 else {
            return weak(t, score: 10)
        }
        return TemplateCandidate(template: t, score: 30, impact: .zero)
    }
}

// MARK: - Helpers

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
