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
                        // 质量评分 Hero 卡片
                        VStack(spacing: 4) {
                            Text(String(format: "%.0f", result.score))
                                .font(.system(size: 72, weight: .bold, design: .rounded))
                                .foregroundColor(qualityColor(for: result.score))
                            Text("Quality Score").font(.subheadline).foregroundColor(.secondary)
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
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal)

                        // 互动率
                        VStack(spacing: 4) {
                            Text("Engagement Rate")
                                .font(.subheadline).foregroundColor(.secondary)
                            Text(String(format: "%.2f%%", result.engagementRate * 100))
                                .font(.title).fontWeight(.semibold)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                        // 权重分解
                        VStack(spacing: 12) {
                            Text("Weight Breakdown").font(.headline)
                            Text("How each interaction type contributes to your quality score")
                                .font(.caption).foregroundColor(.secondary)

                            weightRow(icon: "heart.fill", label: "Likes", weight: result.likesWeight, color: theme.accentPrimary)
                            weightRow(icon: "text.bubble.fill", label: "Comments", weight: result.commentsWeight, color: theme.positiveGreen)
                            weightRow(icon: "arrowshape.turn.up.forward.fill", label: "Shares", weight: result.sharesWeight, color: theme.chartLine)
                        }
                        .padding()
                        .background(.regularMaterial)
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
                    "No Data Available",
                    systemImage: "star.slash",
                    description: Text("Quality scores will appear here once enough engagement data is recorded.")
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

    /// 根据评级标签返回说明文字
    private func qualityDescription(for label: String) -> String {
        switch label {
        case "Excellent": return "Outstanding engagement quality. Your audience is highly responsive and loyal."
        case "Great": return "Strong engagement. Your content resonates well with your followers."
        case "Good": return "Solid engagement. A few tweaks could push you into the top tier."
        case "Fair": return "Average engagement. Experiment with different content types to boost interaction."
        default: return "Low engagement. Consider revamping your content strategy to better connect with your audience."
        }
    }
}
