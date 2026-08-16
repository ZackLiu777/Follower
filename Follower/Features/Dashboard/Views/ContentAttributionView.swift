//
//  ContentAttributionView.swift
//  Follower
//
//  Premium: 内容→增长归因（Phi+）— 什么内容真正涨了粉。
//  ① 归因 Hero：总涨粉 + 最佳类型 + 最佳星期
//  ② 类型贡献条（share 比例）
//  ③ 星期贡献条（7 天）
//  ④ Top 贡献帖子
//  注明"相关性估算"（非因果）。全部 theme 化。
//

import SwiftUI

/// 内容归因详情页
struct ContentAttributionView: View {
    @Environment(\.theme) private var theme

    let result: ContentAttributionResult?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.backgroundGradientColors,
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if let result, result.attributedPosts > 0 {
                        attributionSection(result)
                    } else {
                        ContentUnavailableView(
                            loc(L10n.Premium.attributionNoData),
                            systemImage: "person.badge.plus",
                            description: Text(loc(L10n.Premium.attributionNoDataDesc))
                        )
                        .padding(.top, 80)
                    }
                }
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(loc(L10n.Premium.contentAttribution))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func attributionSection(_ result: ContentAttributionResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // ① Hero
            heroCard(result)

            // ② 类型贡献
            contributionCard(
                title: loc(L10n.Premium.attributionByType),
                rows: result.typeContribution.map { entry in
                    ContributionRowData(
                        label: "\(entry.type)".capitalized,
                        gain: entry.contribution.followerGain,
                        share: entry.contribution.share,
                        icon: entry.type == .reel ? "film.fill" : entry.type == .carousel ? "square.on.square" : "photo"
                    )
                }
            )

            // ③ 星期贡献
            contributionCard(
                title: loc(L10n.Premium.attributionByDay),
                rows: result.weekdayContribution.map { entry in
                    let names = [loc(L10n.Premium.daySun), loc(L10n.Premium.dayMon), loc(L10n.Premium.dayTue),
                                 loc(L10n.Premium.dayWed), loc(L10n.Premium.dayThu), loc(L10n.Premium.dayFri),
                                 loc(L10n.Premium.daySat)]
                    let label = names.indices.contains(entry.weekday - 1) ? names[entry.weekday - 1] : ""
                    return ContributionRowData(
                        label: label,
                        gain: entry.contribution.followerGain,
                        share: entry.contribution.share,
                        icon: "calendar"
                    )
                }
            )

            // ④ Top 帖子
            if !result.topPosts.isEmpty {
                topPostsCard(result.topPosts)
            }

            // 相关性说明
            Text(loc(L10n.Premium.attributionDisclaimer))
                .font(.caption2)
                .foregroundColor(theme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.horizontal)
    }

    // MARK: - Hero

    private func heroCard(_ result: ContentAttributionResult) -> some View {
        VStack(spacing: 8) {
            Text("+\(Int(result.totalAttributedGain.rounded()).formatted(.number))")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(theme.positiveGreen)
            Text(loc(L10n.Premium.attributionTotal))
                .font(.subheadline).foregroundColor(theme.textSecondary)

            HStack(spacing: 10) {
                if let best = result.bestType {
                    heroChip(
                        icon: best == .reel ? "film.fill" : best == .carousel ? "square.on.square" : "photo",
                        text: String(format: loc(L10n.Premium.attributionBestType), "\(best)".capitalized))
                }
                if let day = result.bestWeekday {
                    let names = [loc(L10n.Premium.daySun), loc(L10n.Premium.dayMon), loc(L10n.Premium.dayTue),
                                 loc(L10n.Premium.dayWed), loc(L10n.Premium.dayThu), loc(L10n.Premium.dayFri),
                                 loc(L10n.Premium.daySat)]
                    if names.indices.contains(day - 1) {
                        heroChip(icon: "calendar", text: String(format: loc(L10n.Premium.attributionBestDay), names[day - 1]))
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func heroChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.accentPrimary)
            Text(text)
                .font(.caption).fontWeight(.medium)
                .foregroundColor(theme.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.backgroundSecondary.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 贡献条

    private struct ContributionRowData {
        let label: String
        let gain: Double
        let share: Double
        let icon: String
    }

    private func contributionCard(title: String, rows: [ContributionRowData]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            let enumerated = rows.enumerated().map { $0 }
            ForEach(enumerated, id: \.offset) { item in
                let row = item.element
                HStack(spacing: 10) {
                    Image(systemName: row.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.accentSecondary)
                        .frame(width: 20)
                    Text(row.label)
                        .font(.subheadline)
                        .foregroundColor(theme.textPrimary)
                        .frame(width: 70, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(theme.backgroundSecondary)
                            Capsule()
                                .fill(theme.accentPrimary.opacity(0.75))
                                .frame(width: max(6, geo.size.width * CGFloat(min(1.0, max(0.0, row.share)))))
                        }
                    }
                    .frame(height: 10)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("+\(Int(row.gain.rounded()))")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundColor(theme.positiveGreen)
                        Text("\(Int((row.share * 100).rounded()))%")
                            .font(.caption2).foregroundColor(theme.textTertiary)
                    }
                    .frame(width: 48)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Top 帖子

    private func topPostsCard(_ posts: [AttributedPost]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🏆 \(loc(L10n.Premium.attributionTopPosts))").font(.headline)
            ForEach(Array(posts.enumerated()), id: \.offset) { index, post in
                HStack(spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption).fontWeight(.bold)
                        .foregroundColor(theme.accentPrimary)
                        .frame(width: 18)
                    Image(systemName: post.type == .reel ? "film.fill" : post.type == .carousel ? "square.on.square" : "photo")
                        .font(.caption)
                        .foregroundColor(theme.accentSecondary)
                    Text(post.caption.isEmpty ? loc(L10n.Premium.contentNoCaption) : String(post.caption.prefix(24)))
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    Text("+\(Int(post.attributedFollowers.rounded()))")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(theme.positiveGreen)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
