//
//  DecisionsTimelineView.swift
//  Follower
//
//  方案 B：时间线流。
//  类似 Instagram Feed 的时间线卡片布局，每张卡片带时间戳和圆点指示器，
//  营造社交动态流的视觉感。

import SwiftUI

/// 方案 B — 时间线流视图
///
/// 以垂直时间线排列 ActionCard，每条记录包含时间戳圆点和卡片内容。
/// 视觉风格模仿 Instagram Feed，增强社交媒体的沉浸感。
struct DecisionsTimelineView: View {
    @Environment(\.theme) private var theme
    let cards: [ActionCard]

    var body: some View {
        ScrollView {
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
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Timeline Row

/// 单行时间线条目 — 左侧时间圆点 + 连接线 + 右侧卡片
private struct TimelineCardRow: View {
    let card: ActionCard
    let theme: Theme
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 左侧时间线指示器
            timelineIndicator

            // 右侧卡片内容
            timelineCard
        }
    }

    /// 时间线指示器：圆点 + 上下连接线
    private var timelineIndicator: some View {
        VStack(spacing: 0) {
            // 顶部连接线（非首项显示）
            if !isFirst {
                Rectangle()
                    .fill(theme.divider)
                    .frame(width: 2)
                    .frame(height: 20)
            } else {
                Spacer().frame(height: 20)
            }

            // 时间圆点
            Circle()
                .fill(colorFor(card.type, theme: theme))
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(theme.backgroundGradientStart, lineWidth: 2)
                )

            // 底部连接线（非末项显示）
            if !isLast {
                Rectangle()
                    .fill(theme.divider)
                    .frame(width: 2)
            }
        }
    }

    /// 时间线卡片
    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 时间戳
            HStack(spacing: 4) {
                Circle()
                    .fill(colorFor(card.type, theme: theme))
                    .frame(width: 6, height: 6)
                Text(timestampLabel(for: card.priority))
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)
            }

            // 卡片主体
            VStack(alignment: .leading, spacing: 8) {
                // 图标 + 标题
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

                // 行动列表
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

                // 原因
                Text(card.reason)
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)
                    .lineLimit(2)

                // 效果徽章
                if let impact = card.impact {
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
            .padding(16)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(theme.divider, lineWidth: 0.5)
            )
        }
    }

    /// 将优先级映射为时间戳标签
    /// - Parameter priority: 卡片优先级（越小越早）
    /// - Returns: 时间戳字符串
    private func timestampLabel(for priority: Int) -> String {
        let labels = ["Today · 9:00 AM", "Today · 9:01 AM", "Today · 9:05 AM", "Today · 10:00 AM", "Today · 12:00 PM"]
        let index = min(priority, labels.count - 1)
        return labels[index]
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

#Preview("方案 B — Timeline Feed") {
    let sample = ActionCard.sampleCards
    return NavigationStack {
        DecisionsTimelineView(cards: sample)
    }
}
