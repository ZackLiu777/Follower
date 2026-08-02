//
//  DecisionsTimelineView.swift
//  Follower
//
//  方案 B 重构：时间线流。
//  基于设计稿重构，采用极简现代风格，包含：
//  - 顶部标题栏（Growth Decisions + 副标题 + 刷新按钮）
//  - TODAY 时间线区域（带分类标签、行动按钮、影响值）
//  - COMPLETED TODAY 区域（绿色对勾已完成项）
//
//  设计关键点：
//  - 分类色彩体系：橙 #F97316 / 蓝 #3B82F6 / 紫 #8B5CF6 / 青 #10B981
//  - 时间线：垂直线 + 彩色/灰色圆点
//  - 卡片：圆角 8pt、无描边、轻投影
//  - 分类标签：浅色底 + 深色字
//  - 通用色（背景、文字、分割线等）通过 @Environment(\.theme) 同步

import SwiftUI

// MARK: - Design Tokens (仅分类色彩)

/// 设计稿分类色彩体系
///
/// 仅保留分类专属色（橙/蓝/紫/青 及其浅色变体），
/// 通用色（背景、文字、分割线、卡片背景）统一使用 `theme`。
enum DesignColor {
    private static func rgb(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }

    // 分类色
    static let orange: Color           = rgb("F97316")
    static let blue: Color             = rgb("3B82F6")
    static let purple: Color           = rgb("8B5CF6")
    static let teal: Color             = rgb("10B981")

    // 分类浅色底（标签背景）
    static let orangeLight: Color      = rgb("FED7AA")
    static let blueLight: Color        = rgb("DBEAFE")
    static let purpleLight: Color      = rgb("EDE9FE")
    static let tealLight: Color        = rgb("D1FAE5")
}

// MARK: - CardType → 设计色映射

extension CardType {
    /// 设计稿分类主色
    var designColor: Color {
        switch self {
        case .primary:  return DesignColor.blue
        case .alert:    return DesignColor.orange
        case .recovery: return DesignColor.teal
        case .insight:  return DesignColor.purple
        }
    }

    /// 设计稿分类浅色（标签背景）
    var designLightColor: Color {
        switch self {
        case .primary:  return DesignColor.blueLight
        case .alert:    return DesignColor.orangeLight
        case .recovery: return DesignColor.tealLight
        case .insight:  return DesignColor.purpleLight
        }
    }

    /// 分类标签文字
    var designLabel: String {
        switch self {
        case .primary:  return "Content"
        case .alert:    return "High Priority"
        case .recovery: return "Growth"
        case .insight:  return "Insight"
        }
    }
}

// MARK: - Main View

/// 方案 B 重构 — 时间线流视图
///
/// 保持 `cards: [ActionCard]` 接口与项目其他方案一致。
/// 通用色通过 `@Environment(\.theme)` 同步，分类色使用 `DesignColor`。
struct DecisionsTimelineView: View {
    @Environment(\.theme) private var theme
    let cards: [ActionCard]

    @State private var isRefreshing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 标题区域
                headerSection

                // TODAY 时间线
                todayTimelineSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Header

    /// 顶部标题区域
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Growth Decisions")
                    .font(.system(size: 24, weight: .bold, design: .default))
                    .foregroundColor(theme.textPrimary)

                Text("Smart actions for follower growth")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()

            // 刷新按钮
            Button {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isRefreshing.toggle()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation { isRefreshing = false }
                }
            } label: {
                refreshButtonLabel
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 16)
        .padding(.bottom, 20)
    }

    /// 刷新按钮标签
    private var refreshButtonLabel: some View {
        Image(systemName: "arrow.clockwise")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(theme.textSecondary)
            .frame(width: 36, height: 36)
            // Liquid Glass 玻璃按钮（36pt 圆角 18 ≈ 圆形）
            .followerGlassEffect(cornerRadius: 18)
            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
    }

    // MARK: - Today Timeline Section

    /// TODAY 时间线区域
    private var todayTimelineSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 区域标题
            SectionHeader(title: "TODAY", theme: theme)
                .padding(.bottom, 12)

            // 时间线卡片列表
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
    }

    /// 空状态
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(theme.divider)

            Text("No decisions yet")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - Section Header

/// 区域标题组件（如 "TODAY"、"COMPLETED TODAY"）
private struct SectionHeader: View {
    let title: String
    let theme: Theme

    var body: some View {
        let styledText = Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(theme.textSecondary)
        return styledText.tracking(1.2)
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
            // 左侧时间线指示器
            timelineIndicator

            // 右侧卡片
            decisionCard
        }
    }

    // MARK: Timeline Indicator

    /// 时间线指示器：顶部线 + 圆点 + 底部线
    private var timelineIndicator: some View {
        VStack(spacing: 0) {
            // 顶部连接线
            if !isFirst {
                Rectangle()
                    .fill(theme.divider)
                    .frame(width: 2)
                    .frame(minHeight: 20)
            } else {
                Spacer().frame(height: 20)
            }

            // 时间圆点 — 当前分类色
            Circle()
                .fill(card.type.designColor)
                .frame(width: 12, height: 12)

            // 底部连接线
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
        VStack(alignment: .leading, spacing: 10) {
            // 时间戳
            HStack(spacing: 4) {
                Circle()
                    .fill(card.type.designColor)
                    .frame(width: 6, height: 6)

                Text(timestampLabel(for: card.priority))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(theme.textSecondary)
            }

            // 卡片主体
            cardBody
        }
        .padding(.bottom, bottomPadding)
    }

    /// 卡片主体内容
    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 图标 + 分类标签 + 标题
            HStack(spacing: 10) {
                // 分类图标
                Image(systemName: card.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(card.type.designColor)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    // 分类标签（浅色底 + 深色字）
                    Text(card.type.designLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(card.type.designColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(card.type.designLightColor)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    // 任务标题
                    Text(card.template.displayTitle)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(2)
                }

                Spacer()
            }

            // 行动列表
            VStack(alignment: .leading, spacing: 4) {
                ForEach(card.template.displayActions.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(theme.divider)
                        Text(card.template.displayActions[index])
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(theme.textSecondary)
                            .lineLimit(2)
                    }
                }
            }
            .padding(.leading, 42)

            // 原因
            Text(card.template.displayReason)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(theme.textSecondary)
                .lineLimit(2)
                .padding(.leading, 42)

            // 影响值 + 行动按钮
            HStack {
                // 影响值徽章
                if let impact = card.template.displayImpact {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))

                        Text(impact)
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(card.type.designColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(card.type.designLightColor)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                Spacer()

                // Take action 按钮
                Button {
                    // 行动处理
                } label: {
                    HStack(spacing: 4) {
                        Text("Take action")
                            .font(.system(size: 14, weight: .semibold))

                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(theme.accentPrimary)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 42)
        }
        .padding(16)
        // Liquid Glass 玻璃卡片（与 Dashboard 相同实现/参数）
        .followerGlassEffect(cornerRadius: 8)
    }

    // MARK: Helpers

    /// 将优先级映射为时间戳标签
    private func timestampLabel(for priority: Int) -> String {
        let labels = [
            "Today · 9:00 AM",
            "Today · 9:01 AM",
            "Today · 9:05 AM",
            "Today · 10:00 AM",
            "Today · 12:00 PM"
        ]
        let index = min(priority, labels.count - 1)
        return labels[index]
    }

    /// 底部间距
    private var bottomPadding: CGFloat {
        isLast ? 0 : 4
    }
}

// MARK: - Preview

#Preview("方案 B — Timeline Feed (重构)") {
    let sample = ActionCard.sampleCards
    return NavigationStack {
        DecisionsTimelineView(cards: sample)
    }
}
