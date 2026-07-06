//
//  DecisionsGridView.swift
//  Follower
//
//  方案 C：仪表盘网格。
//  2 列 LazyVGrid 紧凑卡片布局，每张卡片展示图标、标题、关键指标。
//  类似 Apple Fitness 摘要环的仪表盘风格。

import SwiftUI

/// 方案 C — 仪表盘网格视图
///
/// 以 2 列 LazyVGrid 排列紧凑卡片，适合快速概览多个决策建议。
/// 每张卡片仅显示图标、标题和关键数据点，点击可展开详情。
struct DecisionsGridView: View {
    @Environment(\.theme) private var theme
    let cards: [ActionCard]

    /// 2 列弹性网格，间距 12pt
    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(cards) { card in
                    GridCardView(card: card, theme: theme)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Grid Card

/// 网格卡片 — 紧凑布局，图标 + 标题 + 关键指标
private struct GridCardView: View {
    let card: ActionCard
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorFor(card.type, theme: theme).opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: card.icon)
                    .font(.title3)
                    .foregroundColor(colorFor(card.type, theme: theme))
            }

            // 标题
            Text(card.template.displayTitle)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(theme.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // 首要行动或原因（截断）
            Text(card.template.displayActions.first ?? card.template.displayReason)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            // 预期效果 / 数据指标
            metricView
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.divider, lineWidth: 0.5)
        )
    }

    /// 底部指标行：展示 impact 或原因摘要
    @ViewBuilder
    private var metricView: some View {
        if let impact = card.template.displayImpact {
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption2)
                Text(impact)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundColor(theme.positiveGreen)
            .lineLimit(1)
        } else {
            // Alert 类型：展示疲劳标识
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.right")
                    .font(.caption2)
                Text(loc(L10n.Decisions.declining))
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundColor(theme.warningOrange)
            .lineLimit(1)
        }
    }
}

// MARK: - Color Helper

/// 根据卡片类型和主题返回对应的颜色
private func colorFor(_ type: CardType, theme: Theme) -> Color {
    switch type {
    case .primary:  return theme.accentPrimary
    case .alert:    return theme.warningOrange
    case .recovery: return theme.positiveGreen
    case .insight:  return theme.textSecondary
    }
}

// MARK: - Preview

#Preview("方案 C — Dashboard Grid") {
    let sample = ActionCard.sampleCards
    return NavigationStack {
        DecisionsGridView(cards: sample)
    }
}
