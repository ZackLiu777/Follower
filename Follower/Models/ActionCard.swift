//
//  ActionCard.swift
//  Follower
//
//  Growth Decision Engine — 模板注册表驱动的行动卡片。
//  卡片由 DecisionTemplate（注册表条目）实例化，每条建议携带量化收益
//  （CardImpact：预计涨粉数 / 浏览数），数字来自真实数据估算。
//

import Foundation

// MARK: - CardType (7 大类别)

/// 建议类别 — 决定 UI 颜色 / 标签
enum CardType: String, Sendable, CaseIterable {
    /// 内容策略（发布什么）
    case content
    /// 发布时间（什么时候发）
    case timing
    /// 粉丝增长（涨粉 / 留存）
    case growth
    /// 互动留存（点赞 / 评论 / 回复）
    case engagement
    /// 触达曝光（浏览 / reach）
    case reach
    /// 账号健康（异常 / 风险）
    case health
    /// 运营流程（草稿 / 复用 / 计划）
    case ops
}

// MARK: - CardImpact (量化收益)

/// 量化收益 — 建议执行后的估算效果（基于真实数据的转化率估算，非精确值）
struct CardImpact: Sendable {
    /// 预计涨粉数
    let followerGain: Int
    /// 预计浏览增量
    let viewsGain: Int

    /// 是否有可展示的量化收益
    var isQuantified: Bool { followerGain > 0 || viewsGain > 0 }

    static let zero = CardImpact(followerGain: 0, viewsGain: 0)
}

// MARK: - DecisionTemplate (模板注册表条目)

/// 决策模板 — 一条建议的完整定义（触发后实例化为 ActionCard）。
/// 文案通过 key + 参数在显示层实时格式化（支持运行时切换语言）。
struct DecisionTemplate: Identifiable, Sendable {
    /// 模板唯一标识
    let id: String
    /// 建议类别（决定 UI 颜色与标签）
    let type: CardType
    /// SF Symbol 图标名
    let icon: String
    /// 标题 key
    let titleKey: String
    /// 标题格式化参数（%@ 占位，预先格式化的字符串）
    let titleArgs: [String]
    /// 原因 key
    let reasonKey: String
    /// 原因格式化参数
    let reasonArgs: [String]
    /// 行动 key 列表
    let actionKeys: [String]
    /// 行动参数列表（与 actionKeys 一一对应）
    let actionArgsList: [[String]]

    init(id: String, type: CardType, icon: String,
         titleKey: String, titleArgs: [String] = [],
         reasonKey: String, reasonArgs: [String] = [],
         actionKeys: [String], actionArgsList: [[String]] = []) {
        self.id = id
        self.type = type
        self.icon = icon
        self.titleKey = titleKey
        self.titleArgs = titleArgs
        self.reasonKey = reasonKey
        self.reasonArgs = reasonArgs
        self.actionKeys = actionKeys
        self.actionArgsList = actionArgsList
    }
}

// MARK: - Localized Rendering

extension DecisionTemplate {

    var displayTitle: String {
        format(titleKey, titleArgs)
    }

    var displayReason: String {
        format(reasonKey, reasonArgs)
    }

    var displayActions: [String] {
        actionKeys.enumerated().map { index, key in
            let args = index < actionArgsList.count ? actionArgsList[index] : []
            return format(key, args)
        }
    }
}

/// 格式化：无参数直接取本地化文案，有参数走 String(format:)（%@ 占位）
private func format(_ key: String, _ args: [String]) -> String {
    if args.isEmpty { return loc(key) }
    return String(format: loc(key), arguments: args.map { $0 as CVarArg })
}

// MARK: - ActionCard

/// 实例化的建议卡片 — 模板 + 机会分 + 量化收益
struct ActionCard: Identifiable, Sendable {
    /// 唯一实例 id（模板可能多实例化：如多类型疲劳预警）
    let id: String
    /// 模板定义
    let template: DecisionTemplate
    /// 机会分（排序用，越大越优先）
    let priority: Int
    /// 量化收益（预计涨粉 / 浏览）
    let impact: CardImpact
    /// 低置信度 — 数据信号不足时的降级版本（UI 显示「估算」标签）
    let lowConfidence: Bool

    init(id: String, template: DecisionTemplate, priority: Int,
         impact: CardImpact, lowConfidence: Bool = false) {
        self.id = id
        self.template = template
        self.priority = priority
        self.impact = impact
        self.lowConfidence = lowConfidence
    }

    var type: CardType { template.type }
    var icon: String { template.icon }
}

// MARK: - Quantified Impact Rendering

extension ActionCard {

    /// 量化收益文本 — "+69 粉丝 · +1.2K 浏览"（无收益时返回 nil）
    var impactText: String? {
        guard impact.isQuantified else { return nil }
        let fans = "+\(ActionCard.formatCount(impact.followerGain))"
        let views = "+\(ActionCard.formatCount(impact.viewsGain))"
        if impact.followerGain > 0 && impact.viewsGain > 0 {
            return String(format: loc(L10n.Decisions.impactFansViews), fans, views)
        }
        if impact.followerGain > 0 {
            return String(format: loc(L10n.Decisions.impactFansOnly), fans)
        }
        return String(format: loc(L10n.Decisions.impactViewsOnly), views)
    }

    /// 数字缩写：1.2K / 3.4M
    static func formatCount(_ n: Int) -> String {
        if n >= 1_000_000 {
            let v = Double(n) / 1_000_000
            return v.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(v))M" : String(format: "%.1fM", v)
        }
        if n >= 1_000 {
            let v = Double(n) / 1_000
            return v.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(v))K" : String(format: "%.1fK", v)
        }
        return "\(n)"
    }
}

// MARK: - Sample Data

extension ActionCard {
    static let sampleCards: [ActionCard] = [
        ActionCard(id: "1",
            template: DecisionTemplate(id: "sample.boost", type: .content, icon: "flame.fill",
                titleKey: L10n.Decisions.primaryBoostTitle, titleArgs: ["Reel"],
                reasonKey: L10n.Decisions.reasonMomentum, reasonArgs: ["Reel", "2.3"],
                actionKeys: [L10n.Decisions.actionDoubleDown], actionArgsList: [["Reel", "2.3"]]),
            priority: 0,
            impact: CardImpact(followerGain: 69, viewsGain: 1200)),
        ActionCard(id: "2",
            template: DecisionTemplate(id: "sample.fatigue", type: .health, icon: "exclamationmark.triangle.fill",
                titleKey: L10n.Decisions.alertSevereTitle,
                reasonKey: L10n.Decisions.reasonFatigueSevere, reasonArgs: ["Carousel"],
                actionKeys: [L10n.Decisions.actionReducePosts], actionArgsList: [["Carousel"]]),
            priority: 1,
            impact: CardImpact(followerGain: 18, viewsGain: 350)),
        ActionCard(id: "3",
            template: DecisionTemplate(id: "sample.recovery", type: .growth, icon: "arrow.up.heart.fill",
                titleKey: L10n.Decisions.recoveryCriticalTitle,
                reasonKey: L10n.Decisions.reasonCriticalInactive, reasonArgs: ["62"],
                actionKeys: [L10n.Decisions.actionDMFollowers], actionArgsList: [["6"]]),
            priority: 2,
            impact: CardImpact(followerGain: 130, viewsGain: 2400)),
        ActionCard(id: "4",
            template: DecisionTemplate(id: "sample.timing", type: .timing, icon: "lightbulb.fill",
                titleKey: L10n.Decisions.bestPostingTime,
                reasonKey: L10n.Decisions.reasonTimeUplift, reasonArgs: ["Thu 19:00", "1.4"],
                actionKeys: [L10n.Decisions.actionSchedule], actionArgsList: [["Thu", "19:00"]]),
            priority: 3,
            impact: CardImpact(followerGain: 24, viewsGain: 890))
    ]
}
