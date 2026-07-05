//
//  DecisionsStackView.swift
//  Follower
//
//  方案 A：垂直堆叠卡片。
//  经典垂直堆叠布局，每张卡片包含左侧色条、图标、标题、行动列表、
//  原因说明和预期效果徽章。

import SwiftUI

/// 方案 A — 垂直堆叠卡片视图
///
/// 以 ScrollView 垂直排列 ActionCard，每张卡片采用左侧色条 + 内容区的布局。
/// 最接近现有 Dashboard Premium 卡片设计风格。
struct DecisionsStackView: View {
    @Environment(\.theme) private var theme
    let cards: [ActionCard]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(cards) { card in
                    StackCardView(card: card, theme: theme)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Stack Card

/// 堆叠卡片 — 左侧 4pt 色条 + 图标标题行 + 行动列表 + 原因 + 效果徽章
private struct StackCardView: View {
    let card: ActionCard
    let theme: Theme

    var body: some View {
        HStack(spacing: 0) {
            // 左侧色条
            colorBar
                .frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            // 内容区域
            VStack(alignment: .leading, spacing: 10) {
                headerRow
                actionsList
                reasonText
                if let impact = card.impact {
                    impactBadge(impact)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.divider, lineWidth: 0.5)
        )
    }

    /// 左侧颜色条，根据卡片类型决定颜色
    private var colorBar: some View {
        colorFor(card.type, theme: theme)
    }

    /// 图标 + 标题行
    private var headerRow: some View {
        HStack(spacing: 10) {
            Image(systemName: card.icon)
                .font(.title3)
                .foregroundColor(colorFor(card.type, theme: theme))

            Text(card.title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(theme.textPrimary)
                .lineLimit(2)
        }
    }

    /// 行动列表（圆点前缀）
    private var actionsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(card.actions.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundColor(theme.textTertiary)
                    Text(card.actions[index])
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(2)
                }
            }
        }
    }

    /// 原因说明文字
    private var reasonText: some View {
        Text(card.reason)
            .font(.caption)
            .foregroundColor(theme.textTertiary)
            .lineLimit(2)
    }

    /// 预期效果徽章
    private func impactBadge(_ impact: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.up.right")
                .font(.caption2)
            Text(impact)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(theme.positiveGreen)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(theme.positiveGreen.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 6))
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

#Preview("方案 A — Stack Cards") {
    let sample = ActionCard.sampleCards
    return NavigationStack {
        DecisionsStackView(cards: sample)
    }
}
