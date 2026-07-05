//
//  DecisionsListView.swift
//  Follower
//
//  方案 E：紧凑列表。
//  系统原生 List 风格，每行显示图标 + 标题 + 副标题 + 右箭头。
//  适合偏好简洁、高效信息密度的用户。

import SwiftUI

/// 方案 E — 紧凑列表视图
///
/// 使用 List + NavigationLink 实现系统原生列表风格。
/// 每行展示图标、标题和副标题，点击展开完整详情。
/// 底部汇总卡片展示卡片数量统计。
struct DecisionsListView: View {
    @Environment(\.theme) private var theme
    let cards: [ActionCard]

    var body: some View {
        List {
            ForEach(cards) { card in
                NavigationLink {
                    ListCardDetailView(card: card, theme: theme)
                } label: {
                    listRow(card)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .padding(4)
                )
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// 列表行 — 图标 + 标题 + 副标题 + 效果预览
    private func listRow(_ card: ActionCard) -> some View {
        HStack(spacing: 14) {
            // 图标（彩色圆角背景）
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(colorFor(card.type, theme: theme).opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: card.icon)
                    .font(.body)
                    .foregroundColor(colorFor(card.type, theme: theme))
            }

            // 文本区域
            VStack(alignment: .leading, spacing: 3) {
                Text(card.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(card.actions.first ?? card.reason)
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)

                    if let impact = card.impact {
                        Text("·")
                            .foregroundColor(theme.textTertiary)
                        Text(impact)
                            .font(.caption)
                            .foregroundColor(theme.positiveGreen)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // 右箭头
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(theme.textTertiary)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Detail View (Sheet style pushed via NavigationLink)

/// 列表卡片详情页 — 标题 + 完整行动列表 + 原因 + 效果
private struct ListCardDetailView: View {
    let card: ActionCard
    let theme: Theme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 图标 + 标题
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(colorFor(card.type, theme: theme).opacity(0.12))
                                .frame(width: 64, height: 64)

                            Image(systemName: card.icon)
                                .font(.system(size: 28))
                                .foregroundColor(colorFor(card.type, theme: theme))
                        }

                        Text(card.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(theme.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)

                    // 行动列表
                    VStack(alignment: .leading, spacing: 4) {
                        Text(loc(L10n.Decisions.recommendedActions))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.textSecondary)
                            .padding(.bottom, 4)

                        ForEach(card.actions.indices, id: \.self) { index in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1).")
                                    .font(.body)
                                    .foregroundColor(colorFor(card.type, theme: theme))
                                    .fontWeight(.medium)

                                Text(card.actions[index])
                                    .font(.body)
                                    .foregroundColor(theme.textPrimary)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    // 原因
                    VStack(alignment: .leading, spacing: 4) {
                        Text(loc(L10n.Decisions.why))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.textSecondary)

                        Text(card.reason)
                            .font(.body)
                            .foregroundColor(theme.textPrimary)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // 效果
                    if let impact = card.impact {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(loc(L10n.Decisions.expectedImpact))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(theme.textSecondary)

                            HStack(spacing: 8) {
                                Image(systemName: "arrow.up.right")
                                    .font(.body)
                                Text(impact)
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(theme.positiveGreen)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(theme.positiveGreen.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(loc(L10n.Decisions.details))
        .navigationBarTitleDisplayMode(.inline)
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

#Preview("方案 E — Compact List") {
    let sample = ActionCard.sampleCards
    return NavigationStack {
        DecisionsListView(cards: sample)
    }
}
