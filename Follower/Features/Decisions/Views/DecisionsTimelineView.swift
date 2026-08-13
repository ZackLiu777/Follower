//
//  DecisionsTimelineView.swift
//  Follower
//
//  Growth Decisions 时间线流（v3 — 模板注册表版）。
//  设计语言对齐 Premium 详情页（BestTimeView）：
//  - 全部颜色走 theme（9 套主题 + Liquid Glass），删除硬编码色板
//  - 全部文案走 L10n（4 语言），删除硬编码英文与虚构时间戳
//  - Hero 核心指标卡（真实数据：粉丝 / 7 日涨粉 / 7 日浏览）
//  - 主列表（机会分前 6）+ 「更多建议」折叠区（全部按机会分排序）
//  - 刷新按钮触发真实数据刷新
//

import SwiftUI

// MARK: - CardType → 主题色映射

extension CardType {
    /// 分类主色（theme 驱动）— 7 类语义色
    func themeColor(_ theme: Theme) -> Color {
        switch self {
        case .content:     return theme.accentPrimary
        case .timing:      return theme.accentSecondary
        case .growth:      return theme.positiveGreen
        case .engagement:  return theme.warningOrange
        case .reach:       return theme.chartBarGradientStart
        case .health:      return theme.negativeRed
        case .ops:         return theme.textTertiary
        }
    }

    /// 分类标签（本地化）
    var designLabel: String {
        switch self {
        case .content:     return loc(L10n.Decisions.tagContent)
        case .timing:      return loc(L10n.Decisions.tagTiming)
        case .growth:      return loc(L10n.Decisions.tagGrowth)
        case .engagement:  return loc(L10n.Decisions.tagEngagement)
        case .reach:       return loc(L10n.Decisions.tagReach)
        case .health:      return loc(L10n.Decisions.tagHealth)
        case .ops:         return loc(L10n.Decisions.tagOps)
        }
    }
}

// MARK: - Main View

/// Growth Decisions 时间线流视图
/// 仅展示相关性最优的精选建议（≤4 条，类别互不重复）
struct DecisionsTimelineView: View {
    @Environment(\.theme) private var theme
    let hero: DecisionSummary?
    let cards: [ActionCard]
    let onRefresh: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let hero {
                    heroCard(hero)
                    if hero.timeUplift > 1.05 {
                        bestTimeCard(hero)
                    }
                }

                SectionHeader(title: loc(L10n.Decisions.todayActions), theme: theme)
                    .padding(.top, 4)

                if cards.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                            TimelineCardRow(
                                card: card,
                                theme: theme,
                                isFirst: index == 0,
                                isLast: index == cards.count - 1
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
    }

    // MARK: - Hero Card

    /// Hero 核心指标卡：当前粉丝 + 7 日涨粉 + 7 日浏览（真实数据）
    private func heroCard(_ hero: DecisionSummary) -> some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(hero.followers.formatted())
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)

                Text(loc(L10n.Decisions.heroFollowers))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(theme.textSecondary)
            }

            HStack(spacing: 10) {
                heroChip(icon: "person.badge.plus",
                         value: signed(hero.growth7d),
                         title: loc(L10n.Decisions.heroGrowth7d))
                heroChip(icon: "eye.fill",
                         value: signed(hero.views7d),
                         title: loc(L10n.Decisions.heroViews7d))
            }

            // 数据新鲜度 — 基于最近一次同步的快照时间
            if let dataDate = hero.dataDate {
                Text(String(format: loc(L10n.Decisions.basedOnData),
                    dataDate.formatted(date: .abbreviated, time: .shortened)))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(theme.textTertiary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.divider, lineWidth: 0.5))
        .shadow(color: .black.opacity(theme.isDark ? 0.10 : 0.05), radius: 8, y: 2)
    }

    /// Hero 子指标 chip：涨粉 / 浏览（正绿负红），上数字下标题
    private func heroChip(icon: String, value: String, title: String) -> some View {
        let isNegative = value.hasPrefix("-")
        let tint = isNegative ? theme.negativeRed : theme.positiveGreen

        return VStack(spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(tint)

                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(tint)
            }

            Text(title)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(theme.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(theme.backgroundSecondary.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    /// 带符号数字：+123 / -45（0 → +0 保持绿色）
    private func signed(_ n: Int) -> String {
        n >= 0 ? "+\(ActionCard.formatCount(n))" : "-\(ActionCard.formatCount(abs(n)))"
    }

    // MARK: - Best Time Card

    /// 最佳时段推荐卡（互动提升倍数来自真实帖子分布）
    private func bestTimeCard(_ hero: DecisionSummary) -> some View {
        let dayName = dayNames[clamp(hero.bestDay - 1, 0, 6)]
        let line = String(format: loc(L10n.Decisions.reasonTimeUplift),
            "\(dayName) \(hero.bestHours)", String(format: "%.1f", hero.timeUplift))

        return HStack(spacing: 12) {
            Image(systemName: "clock.badge.checkmark.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(theme.accentSecondary)
                .frame(width: 44, height: 44)
                .background(theme.accentSecondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(loc(L10n.Decisions.bestPostingTime))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textPrimary)

                Text(line)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(16)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.divider, lineWidth: 0.5))
    }

    // MARK: - Empty State

    /// 空状态（无数据 / 无建议）
    private var emptyStateView: some View {
        ContentUnavailableView(
            loc(L10n.Decisions.noDecisions),
            systemImage: "lightbulb",
            description: Text(loc(L10n.Decisions.noDecisionsMessage))
        )
        .padding(.top, 60)
    }
}

// MARK: - Section Header

/// 区域标题组件（如 "TODAY'S ACTIONS"）
private struct SectionHeader: View {
    let title: String
    let theme: Theme

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(theme.textSecondary)
            .tracking(1.2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Timeline Card Row

/// 时间线单行 — 左侧圆点 + 连接线 + 右侧卡片
private struct TimelineCardRow: View {
    let card: ActionCard
    let theme: Theme
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            timelineIndicator
            decisionCard
        }
    }

    // MARK: Timeline Indicator

    /// 时间线指示器：顶部线 + 圆点 + 底部线（分类色）
    private var timelineIndicator: some View {
        VStack(spacing: 0) {
            if !isFirst {
                Rectangle()
                    .fill(theme.divider)
                    .frame(width: 2)
                    .frame(minHeight: 20)
            } else {
                Spacer().frame(height: 20)
            }

            Circle()
                .fill(card.type.themeColor(theme))
                .frame(width: 12, height: 12)

            if !isLast {
                Rectangle()
                    .fill(theme.divider)
                    .frame(width: 2)
            }
        }
    }

    // MARK: Decision Card

    /// 右侧决策卡片
    private var decisionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader
            actionsList
            cardFooter
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.decisionCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.divider, lineWidth: 0.5))
        .shadow(color: .black.opacity(theme.isDark ? 0.06 : 0.03), radius: 4, y: 1)
        .padding(.bottom, isLast ? 0 : 4)
    }

    /// 卡片头部：图标 tile + 分类标签 + 估算标签 + 标题
    private var cardHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: card.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(card.type.themeColor(theme))
                .frame(width: 40, height: 40)
                .background(card.type.themeColor(theme).opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(card.type.designLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(card.type.themeColor(theme))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(card.type.themeColor(theme).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    if card.lowConfidence {
                        Text(loc(L10n.Decisions.estimation))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.textTertiary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(theme.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                Text(card.template.displayTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
            }

            Spacer()
        }
    }

    /// 行动列表
    private var actionsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(card.template.displayActions.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(card.type.themeColor(theme))
                        .frame(width: 5, height: 5)
                        .padding(.top, 6)

                    Text(card.template.displayActions[index])
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.leading, 6)
    }

    /// 底部：量化收益徽章 + 行动按钮
    private var cardFooter: some View {
        HStack {
            if let impact = card.impactText {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))

                    Text(impact)
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(card.type.themeColor(theme))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(card.type.themeColor(theme).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Spacer()

            Button {
            } label: {
                HStack(spacing: 4) {
                    Text(loc(L10n.Decisions.takeAction))
                        .font(.system(size: 14, weight: .semibold))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(theme.accentPrimary)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 6)
    }
}

// MARK: - Helpers

private let dayNames = [
    loc(L10n.Premium.daySun), loc(L10n.Premium.dayMon), loc(L10n.Premium.dayTue),
    loc(L10n.Premium.dayWed), loc(L10n.Premium.dayThu), loc(L10n.Premium.dayFri),
    loc(L10n.Premium.daySat)
]

private func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int { Swift.min(hi, Swift.max(lo, v)) }

// MARK: - Preview

#Preview("DecisionsTimelineView — Hero + Cards") {
    let hero = DecisionSummary(
        followers: 12840, growth7d: 86, views7d: 3200,
        bestHours: "19:00–21:00", bestDay: 4, timeUplift: 1.4,
        dataDate: Date()
    )
    return NavigationStack {
        DecisionsTimelineView(
            hero: hero,
            cards: ActionCard.sampleCards,
            onRefresh: {}
        )
    }
}

#Preview("DecisionsTimelineView — 空态") {
    return NavigationStack {
        DecisionsTimelineView(hero: nil, cards: [], onRefresh: {})
    }
}
