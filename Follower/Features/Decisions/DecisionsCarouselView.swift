//
//  DecisionsCarouselView.swift
//  Follower
//
//  方案 D：轮播翻页。
//  水平 TabView 翻页设计，每页一张完整卡片。
//  类似 App Store Today 卡片的沉浸式浏览体验。

import SwiftUI

/// 方案 D — 轮播翻页视图
///
/// 使用 TabView + .tabViewStyle(.page) 实现水平翻页浏览。
/// 每页展示一张完整决策卡片，包含大图标、标题、行动列表、原因和效果。
/// 底部页面指示器帮助用户了解当前位置。
struct DecisionsCarouselView: View {
    @Environment(\.theme) private var theme
    let cards: [ActionCard]

    /// 当前页面索引，驱动自定义页面指示器
    @State private var currentPage: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    CarouselCardView(card: card, theme: theme)
                        .tag(index)
                        .padding(.horizontal, 20)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // 自定义页面指示器
            pageIndicator
                .padding(.bottom, 16)
        }
    }

    /// 自定义圆点页面指示器
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(cards.indices, id: \.self) { index in
                Circle()
                    .fill(index == currentPage
                          ? colorFor(cards[index].type, theme: theme)
                          : theme.divider)
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
    }
}

// MARK: - Carousel Card

/// 轮播卡片 — 单页布局，大图标 + 标题 + 行动 + 原因 + 效果
private struct CarouselCardView: View {
    let card: ActionCard
    let theme: Theme

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // 大图标
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(colorFor(card.type, theme: theme).opacity(0.12))
                    .frame(width: 80, height: 80)

                Image(systemName: card.icon)
                    .font(.system(size: 36))
                    .foregroundColor(colorFor(card.type, theme: theme))
            }

            // 标题
            Text(card.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(theme.textPrimary)
                .multilineTextAlignment(.center)

            // 行动列表（带序号）
            VStack(alignment: .leading, spacing: 8) {
                ForEach(card.actions.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(colorFor(card.type, theme: theme))
                            .frame(width: 22, height: 22)
                            .background(
                                Circle()
                                    .fill(colorFor(card.type, theme: theme).opacity(0.12))
                            )

                        Text(card.actions[index])
                            .font(.body)
                            .foregroundColor(theme.textSecondary)
                            .lineLimit(2)
                    }
                }
            }
            .padding(.horizontal, 16)

            // 原因
            Text(card.reason)
                .font(.caption)
                .foregroundColor(theme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            // 效果徽章
            if let impact = card.impact {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right")
                        .font(.subheadline)
                    Text(impact)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(theme.positiveGreen)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(theme.positiveGreen.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(theme.divider, lineWidth: 0.5)
        )
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

#Preview("方案 D — Carousel Pager") {
    let sample = ActionCard.sampleCards
    return NavigationStack {
        DecisionsCarouselView(cards: sample)
    }
}
