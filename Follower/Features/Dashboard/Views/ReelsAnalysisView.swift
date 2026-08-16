//
//  ReelsAnalysisView.swift
//  Follower
//
//  Premium: Reels 深度分析（Phi+）— 完播率 / Saves / Shares 权重。
//  ① Hero：平均完播率 + 最佳 Reel
//  ② 权重卡：Saves 率 / Shares 率（推荐算法核心驱动）
//  ③ Reel 列表（每帖：播放 / 完播率 / Saves / Shares）
//  全部 theme 化；无数据 → 空态（开发模式 insights 空数组兜底）。
//

import SwiftUI

/// Reels 深度分析详情页
struct ReelsAnalysisView: View {
    @Environment(\.theme) private var theme

    let result: ReelsAnalysisResult?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.backgroundGradientColors,
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if let result, result.reelCount > 0 {
                        heroCard(result)
                        weightCard(result)
                        reelListCard(result.reels)
                        captionNote
                    } else {
                        ContentUnavailableView(
                            loc(L10n.Premium.reelsNoData),
                            systemImage: "play.rectangle.fill",
                            description: Text(loc(L10n.Premium.reelsNoDataDesc))
                        )
                        .padding(.top, 80)
                    }
                }
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(loc(L10n.Premium.reelsAnalysis))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private func heroCard(_ result: ReelsAnalysisResult) -> some View {
        VStack(spacing: 8) {
            Text(ReelsAnalysisService.percent(result.avgCompletionRate))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(theme.accentPrimary)
            Text(loc(L10n.Premium.reelsAvgCompletion))
                .font(.subheadline).foregroundColor(theme.textSecondary)

            if let best = result.bestReel {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12))
                        .foregroundColor(theme.warningOrange)
                    Text(String(format: loc(L10n.Premium.reelsBest),
                                ReelsAnalysisService.percent(best.completionRate)))
                        .font(.caption).fontWeight(.medium)
                        .foregroundColor(theme.textSecondary)
                }
            }
            Text(loc(L10n.Premium.reelsCount))
                .font(.caption2).foregroundColor(theme.textTertiary)
                .padding(.top, 2)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - 权重卡

    private func weightCard(_ result: ReelsAnalysisResult) -> some View {
        HStack(spacing: 10) {
            weightBlock(
                icon: "bookmark.fill",
                title: loc(L10n.Premium.reelsSaveRate),
                value: ReelsAnalysisService.percent(result.avgSaveRate))
            weightBlock(
                icon: "arrowshape.turn.up.right.fill",
                title: loc(L10n.Premium.reelsShareRate),
                value: ReelsAnalysisService.percent(result.avgShareRate))
        }
        .padding(.horizontal)
    }

    private func weightBlock(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(theme.accentSecondary)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)
            Text(title)
                .font(.caption2).foregroundColor(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Reel 列表

    private func reelListCard(_ reels: [ReelPerformance]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(loc(L10n.Premium.reelsList)).font(.headline)
            ForEach(Array(reels.enumerated()), id: \.element.mediaID) { index, reel in
                HStack(spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption).fontWeight(.bold)
                        .foregroundColor(theme.accentPrimary)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reel.caption.isEmpty ? loc(L10n.Premium.reelsNoCaption) : String(reel.caption.prefix(22)))
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                            .lineLimit(1)
                        Text("\(Int(reel.plays).formatted(.number)) \(loc(L10n.Premium.reelsPlays)) · \(Int(reel.duration))s")
                            .font(.caption2)
                            .foregroundColor(theme.textTertiary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(ReelsAnalysisService.percent(reel.completionRate))
                            .font(.caption).fontWeight(.semibold)
                            .foregroundColor(theme.accentPrimary)
                        Text("S \(Int(reel.saves)) · ⤴ \(Int(reel.shares))")
                            .font(.caption2)
                            .foregroundColor(theme.textTertiary)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var captionNote: some View {
        Text(loc(L10n.Premium.reelsNote))
            .font(.caption2)
            .foregroundColor(theme.textTertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
    }
}

// MARK: - Preview

#Preview("Reels 深度分析 — 有数据") {
    let sample = ReelsAnalysisResult(
        reelCount: 3,
        avgCompletionRate: 0.62,
        avgSaveRate: 0.045,
        avgShareRate: 0.028,
        bestReel: ReelPerformance(
            mediaID: "r1", caption: "夏日旅行 vlog 🎬", duration: 30,
            plays: 15200, completionRate: 0.78,
            saves: 760, shares: 420, saveRate: 0.05, shareRate: 0.028),
        reels: [
            ReelPerformance(mediaID: "r1", caption: "夏日旅行 vlog 🎬", duration: 30,
                plays: 15200, completionRate: 0.78, saves: 760, shares: 420,
                saveRate: 0.05, shareRate: 0.028),
            ReelPerformance(mediaID: "r2", caption: "健身打卡第 30 天 💪", duration: 22,
                plays: 8900, completionRate: 0.61, saves: 320, shares: 210,
                saveRate: 0.036, shareRate: 0.024),
            ReelPerformance(mediaID: "r3", caption: "深夜碎碎念", duration: 40,
                plays: 5400, completionRate: 0.47, saves: 180, shares: 95,
                saveRate: 0.033, shareRate: 0.018),
        ]
    )
    return NavigationStack {
        ReelsAnalysisView(result: sample)
    }
}

#Preview("Reels 深度分析 — 空态") {
    return NavigationStack {
        ReelsAnalysisView(result: nil)
    }
}
