//
//  QualityDetailView.swift
//  Follower
//
//  Gamma: Premium 详情 — 互动质量评分。

import SwiftUI

/// Premium 详情页：展示互动质量评分及其维度分解（点赞/评论/分享权重）
struct QualityDetailView: View {
    /// 主题环境
    @Environment(\.theme) private var theme

    /// 互动质量评分结果
    let result: ScoringResult?

    /// 质量评分 Hero + 各维度权重分解 + 评级标签 UI
    var body: some View {
        ZStack {
            // Theme background gradient
            LinearGradient(
                colors: theme.backgroundGradientColors,
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            if let result = result {
                ScrollView {
                    VStack(spacing: 20) {
                        // 质量评分 Hero 卡片：环形仪表 + 评级胶囊
                        VStack(spacing: 8) {
                            ScoreGaugeView(score: result.score, size: 140)
                            Text(loc(L10n.Premium.qualityScore)).font(.subheadline).foregroundColor(.secondary)
                            Text(result.label)
                                .font(.headline)
                                .foregroundColor(qualityColor(for: result.score))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(qualityColor(for: result.score).opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(theme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal)

                        // 互动率：数字 + 占比条
                        VStack(spacing: 10) {
                            HStack {
                                Text(loc(L10n.Premium.engagementRate))
                                    .font(.subheadline).foregroundColor(.secondary)
                                Spacer()
                                Text(String(format: "%.2f%%", result.engagementRate * 100))
                                    .font(.title3).fontWeight(.semibold)
                                    .foregroundColor(qualityColor(for: result.score))
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4).fill(theme.divider)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(qualityColor(for: result.score))
                                        .frame(width: geo.size.width * min(max(result.engagementRate, 0), 1))
                                }
                            }
                            .frame(height: 10)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(theme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                        // 权重分解
                        VStack(spacing: 12) {
                            Text(loc(L10n.Premium.weightBreakdown)).font(.headline)
                            Text(loc(L10n.Premium.weightBreakdownDesc))
                                .font(.caption).foregroundColor(.secondary)

                            weightRow(icon: "heart.fill", label: loc(L10n.Premium.likes), weight: result.likesWeight, color: theme.accentPrimary)
                            weightRow(icon: "text.bubble.fill", label: loc(L10n.Premium.comments), weight: result.commentsWeight, color: theme.positiveGreen)
                            weightRow(icon: "arrowshape.turn.up.forward.fill", label: loc(L10n.Premium.shares), weight: result.sharesWeight, color: theme.chartLine)
                        }
                        .padding()
                        .background(theme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                        // 评分说明
                        Text(qualityDescription(for: result.label))
                            .font(.caption).foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                .scrollContentBackground(.hidden)
            } else {
                // 无数据占位
                ContentUnavailableView(
                    loc(L10n.Premium.noDataAvailable),
                    systemImage: "star.slash",
                    description: Text(loc(L10n.Premium.noDataQualityDesc))
                )
            }
        }
        .navigationTitle(loc(L10n.Premium.engagementQuality))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helper Views

    /// 权重行：SF Symbol + 标签 + 倍数说明 + 权重值
    private func weightRow(icon: String, label: String, weight: Double, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text("x\(String(format: "%.0f", weight))")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundColor(color)
        }
    }

    // MARK: - Helpers

    /// 根据评分返回对应颜色
    private func qualityColor(for score: Double) -> Color {
        switch score {
        case 80...100: return theme.positiveGreen
        case 60..<80: return theme.accentPrimary
        case 40..<60: return theme.warningOrange
        default: return theme.negativeRed
        }
    }

    /// 根据评级标签返回说明文字（本地化 tip）
    private func qualityDescription(for label: String) -> String {
        switch label {
        case "Excellent": return loc(L10n.Premium.tipExcellent)
        case "Great": return loc(L10n.Premium.tipGreat)
        case "Good": return loc(L10n.Premium.tipGood)
        case "Fair": return loc(L10n.Premium.tipFair)
        default: return loc(L10n.Premium.tipLowQuality)
        }
    }
}
