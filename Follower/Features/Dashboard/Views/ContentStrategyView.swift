//
//  ContentStrategyView.swift
//  Follower
//
//  Phi: Premium 详情 — 内容策略（v2 数据驱动版）。
//  两层：
//  ① 内容档案 — 类型表现矩阵 / 互动档位分布 / 爆款公式 / Top 帖子
//  ② 互动漏斗 — 浏览→互动→涨粉 转化诊断 + 量化机会
//  全部 theme 化；无数据时显示空态。
//

import SwiftUI

/// Premium 详情页：内容档案 + 互动漏斗
struct ContentStrategyView: View {
    @Environment(\.theme) private var theme

    /// 内容档案结果（nil = 无帖子数据）
    let profile: ContentProfileResult?
    /// 互动漏斗结果（nil = 快照不足）
    let funnel: EngagementFunnelResult?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.backgroundGradientColors,
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if profile == nil && funnel == nil {
                        ContentUnavailableView(
                            loc(L10n.Premium.contentStrategyNoData),
                            systemImage: "chart.bar.doc.horizontal",
                            description: Text(loc(L10n.Premium.contentStrategyNoDataDesc))
                        )
                        .padding(.top, 80)
                    } else {
                        if let profile {
                            profileSection(profile)
                        }
                        if let funnel {
                            funnelSection(funnel)
                        }
                    }
                }
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(loc(L10n.Premium.contentStrategy))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - ① 内容档案

    private func profileSection(_ profile: ContentProfileResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(loc(L10n.Premium.contentProfileTitle))

            // 类型表现矩阵
            VStack(alignment: .leading, spacing: 10) {
                Text(loc(L10n.Premium.contentProfileTypes)).font(.headline)
                ForEach(profile.typeBands, id: \.type) { band in
                    HStack(spacing: 10) {
                        Text("\(band.type)".capitalized)
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(theme.textPrimary)
                            .frame(width: 76, alignment: .leading)
                        // 互动条
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(theme.backgroundSecondary)
                                Capsule()
                                    .fill(theme.accentPrimary.opacity(0.75))
                                    .frame(width: max(8, geo.size.width * CGFloat(profile.averageEngagement > 0 ? band.avgEngagement / profile.averageEngagement : 0)))
                            }
                        }
                        .frame(height: 10)
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(Int(band.avgEngagement.rounded()).formatted(.number))
                                .font(.caption).fontWeight(.semibold)
                                .foregroundColor(theme.textPrimary)
                            Text("\(band.postCount)\(loc(L10n.Premium.contentProfilePosts))")
                                .font(.caption2).foregroundColor(theme.textTertiary)
                        }
                        .frame(width: 64)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // 互动档位分布
            HStack(spacing: 10) {
                tierBadge(title: loc(L10n.Premium.contentTierViral),
                          count: profile.viralCount,
                          color: theme.accentSecondary)
                tierBadge(title: loc(L10n.Premium.contentTierAverage),
                          count: profile.averageCount,
                          color: theme.accentPrimary)
                tierBadge(title: loc(L10n.Premium.contentTierLow),
                          count: profile.lowCount,
                          color: theme.textTertiary)
            }

            // 爆款公式
            if let formula = profile.viralFormula {
                viralFormulaCard(formula)
            }

            // caption 相关性
            if let insight = profile.captionInsight {
                captionInsightCard(insight)
            }

            // Top 5
            if !profile.topPosts.isEmpty {
                topPostsCard(profile.topPosts)
            }
        }
        .padding(.horizontal)
    }

    private func tierBadge(title: String, count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(title)
                .font(.caption2).foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func viralFormulaCard(_ formula: ViralFormula) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("⚡ \(loc(L10n.Premium.contentViralFormula))")
                .font(.headline)
            if let type = formula.dominantType {
                formulaRow(icon: "film.fill",
                           text: String(format: loc(L10n.Premium.contentFormulaType), "\(type)".capitalized))
            }
            if let day = formula.dominantWeekday {
                let names = [loc(L10n.Premium.daySun), loc(L10n.Premium.dayMon), loc(L10n.Premium.dayTue),
                             loc(L10n.Premium.dayWed), loc(L10n.Premium.dayThu), loc(L10n.Premium.dayFri),
                             loc(L10n.Premium.daySat)]
                if names.indices.contains(day - 1) {
                    formulaRow(icon: "calendar",
                               text: String(format: loc(L10n.Premium.contentFormulaDay), names[day - 1]))
                }
            }
            if let hour = formula.dominantHour {
                formulaRow(icon: "clock",
                           text: String(format: loc(L10n.Premium.contentFormulaHour), String(format: "%02d:00", hour)))
            }
            if formula.avgCaptionLength > 0 || formula.avgCaptionLengthOthers > 0 {
                formulaRow(icon: "text.alignleft",
                           text: String(format: loc(L10n.Premium.contentFormulaCaption),
                                        Int(formula.avgCaptionLength.rounded()),
                                        Int(formula.avgCaptionLengthOthers.rounded())))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func formulaRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.accentSecondary)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
        }
    }

    private func captionInsightCard(_ insight: (longAvg: Double, shortAvg: Double)) -> some View {
        let longWins = insight.longAvg >= insight.shortAvg
        return HStack(spacing: 10) {
            Image(systemName: "text.bubble")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(theme.accentPrimary)
            Text(String(format: loc(L10n.Premium.contentCaptionInsight),
                        Int(longWins ? insight.longAvg.rounded() : insight.shortAvg.rounded()),
                        Int(longWins ? insight.shortAvg.rounded() : insight.longAvg.rounded())))
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
            Spacer()
        }
        .padding()
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func topPostsCard(_ posts: [TopContentPost]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🏆 \(loc(L10n.Premium.contentTopPosts))").font(.headline)
            ForEach(Array(posts.enumerated()), id: \.offset) { index, post in
                HStack(spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption).fontWeight(.bold)
                        .foregroundColor(theme.accentPrimary)
                        .frame(width: 18)
                    Image(systemName: post.type == .reel ? "film.fill" : post.type == .carousel ? "square.on.square" : "photo")
                        .font(.caption)
                        .foregroundColor(theme.accentSecondary)
                    Text(post.caption.isEmpty ? loc(L10n.Premium.contentNoCaption) : String(post.caption.prefix(28)))
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(post.engagement.formatted(.number))")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(theme.textPrimary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - ② 互动漏斗

    private func funnelSection(_ funnel: EngagementFunnelResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(loc(L10n.Premium.contentFunnelTitle))

            // 三环节漏斗可视化
            VStack(spacing: 10) {
                funnelStage(icon: "eye.fill",
                            title: loc(L10n.Premium.contentFunnelViews),
                            value: funnel.viewsDelta.formatted(.number))
                funnelStage(icon: "hand.tap.fill",
                            title: loc(L10n.Premium.contentFunnelEngagement),
                            value: funnel.engagementDelta.formatted(.number))
                funnelStage(icon: "person.badge.plus",
                            title: loc(L10n.Premium.contentFunnelFollowers),
                            value: funnel.followersDelta.formatted(.number))
            }
            .padding()
            .background(theme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // 转化率
            HStack(spacing: 10) {
                funnelRate(title: loc(L10n.Premium.contentFunnelViewToEng),
                           value: String(format: "%.2f%%", funnel.viewToEngagement * 100))
                funnelRate(title: loc(L10n.Premium.contentFunnelEngToFollower),
                           value: String(format: "%.2f%%", funnel.engagementToFollower * 100))
                funnelRate(title: loc(L10n.Premium.contentFunnelOverall),
                           value: String(format: "%.3f%%", funnel.viewToFollower * 100))
            }

            // 瓶颈 + 机会
            if funnel.bottleneck != .none {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(theme.warningOrange)
                    Text(String(format: loc(L10n.Premium.contentFunnelBottleneck),
                                bottleneckLabel(funnel.bottleneck)))
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                    Text("+\(funnel.opportunityFollowers.formatted(.number))")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(theme.positiveGreen)
                }
                .padding()
                .background(theme.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(.horizontal)
    }

    private func funnelStage(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.accentPrimary)
                .frame(width: 20)
            Text(title)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
            Spacer()
            Text(value)
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(theme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(theme.backgroundSecondary.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func funnelRate(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(theme.accentPrimary)
            Text(title)
                .font(.caption2).foregroundColor(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func bottleneckLabel(_ bottleneck: EngagementFunnelResult.Bottleneck) -> String {
        switch bottleneck {
        case .engagement: return loc(L10n.Premium.contentBottleneckEngagement)
        case .conversion: return loc(L10n.Premium.contentBottleneckConversion)
        case .none: return ""
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(theme.textPrimary)
    }
}
