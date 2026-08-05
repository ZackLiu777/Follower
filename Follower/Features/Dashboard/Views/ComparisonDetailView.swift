//
//  ComparisonDetailView.swift
//  Follower
//
//  Gamma: Premium 详情 — 长期趋势对比。

import SwiftUI

/// Premium 详情页：展示两个时间周期的指标对比（当前 vs 前一个周期）
struct ComparisonDetailView: View {
    /// 主题环境
    @Environment(\.theme) private var theme

    /// 周期对比结果
    let result: ComparisonResult?

    /// 周期均值对比 + 变化方向 + 变化百分比 UI
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
                        // 变化方向 Hero 卡片
                        VStack(spacing: 8) {
                            Image(systemName: directionIcon(for: result.direction))
                                .font(.system(size: 48))
                                .foregroundColor(directionColor(for: result.direction))

                            Text(directionLabel(for: result.direction))
                                .font(.title).fontWeight(.bold)
                                .foregroundColor(directionColor(for: result.direction))

                            Text(String(format: "%+.1f%%", result.percentChange))
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundColor(directionColor(for: result.direction))
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal)

                        // 当前 vs 前周期均值对比
                        HStack(spacing: 16) {
                            comparisonCard(
                                title: "Previous Period",
                                value: String(format: "%.0f", result.previousAvg),
                                color: theme.textSecondary
                            )
                            comparisonCard(
                                title: "Current Period",
                                value: String(format: "%.0f", result.currentAvg),
                                color: directionColor(for: result.direction)
                            )
                        }
                        .padding(.horizontal)

                        // 绝对变化量
                        VStack(spacing: 4) {
                            Text("Absolute Change")
                                .font(.subheadline).foregroundColor(.secondary)
                            Text(String(format: "%+.0f", result.absoluteChange))
                                .font(.title2).fontWeight(.bold)
                                .foregroundColor(directionColor(for: result.direction))
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                        // 说明文字
                        Text(comparisonDescription(for: result.direction, percent: result.percentChange))
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
                    systemImage: "chart.line.flip",
                    description: Text("Comparison data will appear here once enough historical data is recorded.")
                )
            }
        }
        .navigationTitle(loc(L10n.Premium.longTermComparison))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helper Views

    /// 周期对比卡片：标题 + 数值 + 颜色
    private func comparisonCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2).fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    /// 根据对比方向返回 SF Symbol 图标名
    private func directionIcon(for direction: ComparisonDirection) -> String {
        switch direction {
        case .up: return "arrow.up.circle.fill"
        case .down: return "arrow.down.circle.fill"
        case .flat: return "equal.circle.fill"
        }
    }

    /// 根据对比方向返回文字标签
    private func directionLabel(for direction: ComparisonDirection) -> String {
        switch direction {
        case .up: return "Growing"
        case .down: return "Declining"
        case .flat: return "Stable"
        }
    }

    /// 根据对比方向返回对应颜色
    private func directionColor(for direction: ComparisonDirection) -> Color {
        switch direction {
        case .up: return theme.positiveGreen
        case .down: return theme.negativeRed
        case .flat: return theme.textSecondary
        }
    }

    /// 根据对比方向和百分比返回说明文字
    private func comparisonDescription(for direction: ComparisonDirection, percent: Double) -> String {
        switch direction {
        case .up:
            return String(format: "Your metrics are up %.1f%% compared to the previous period. Keep doing what you're doing!", abs(percent))
        case .down:
            return String(format: "Your metrics are down %.1f%% compared to the previous period. Review recent content changes to identify causes.", abs(percent))
        case .flat:
            return "Your metrics are stable compared to the previous period. Consider experimenting with new content types to spark growth."
        }
    }
}
