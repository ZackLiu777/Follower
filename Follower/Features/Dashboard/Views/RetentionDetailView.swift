//
//  RetentionDetailView.swift
//  Follower
//
//  Gamma: Premium 详情 — 留存与流失分析。

import SwiftUI

/// Premium 详情页：展示留存率、流失风险、净增长等留存分析指标
struct RetentionDetailView: View {
    /// 主题环境
    @Environment(\.theme) private var theme

    /// 留存/流失分析结果
    let result: RetentionResult?

    /// 净增长率 Hero + 风险等级 + 粉丝变化 + 日均变化 UI
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
                        // 净增长率 Hero 卡片：箭头 + 百分比
                        VStack(spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: result.netGrowthRate >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 36, weight: .semibold))
                                    .foregroundColor(result.netGrowthRate >= 0 ? theme.positiveGreen : theme.negativeRed)
                                Text(String(format: "%+.1f%%", result.netGrowthRate * 100))
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundColor(result.netGrowthRate >= 0 ? theme.positiveGreen : theme.negativeRed)
                            }
                            Text(loc(L10n.Premium.netGrowthRate)).font(.subheadline).foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(theme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal)

                        // 流失风险等级卡片：量表条 + 等级 + 流失警告
                        VStack(spacing: 10) {
                            HStack {
                                Text(loc(L10n.Premium.churnRiskLevel)).font(.headline)
                                Spacer()
                                Text(result.churnRiskLevel)
                                    .font(.headline).fontWeight(.bold)
                                    .foregroundColor(churnColor(for: result.churnRiskLevel))
                            }
                            SegmentedScaleView(
                                level: churnLevel(for: result.churnRiskLevel),
                                levelColor: churnColor(for: result.churnRiskLevel),
                                levelLabel: result.churnRiskLevel
                            )
                            if result.isChurning {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(theme.warningOrange)
                                    Text(loc(L10n.Premium.churnDetected))
                                        .font(.caption).foregroundColor(theme.warningOrange)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(theme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                        // 粉丝变化对比
                        HStack(spacing: 20) {
                            statCard(
                                title: loc(L10n.Premium.start),
                                value: result.startFollowers.formatted(.number),
                                color: theme.textSecondary
                            )
                            Image(systemName: "arrow.right")
                                .foregroundColor(.secondary)
                            statCard(
                                title: loc(L10n.Premium.end),
                                value: result.endFollowers.formatted(.number),
                                color: result.netGrowthRate >= 0 ? theme.positiveGreen : theme.negativeRed
                            )
                        }
                        .padding(.horizontal)

                        // 日均变化
                        VStack(spacing: 4) {
                            Text(loc(L10n.Premium.avgDailyChange))
                                .font(.subheadline).foregroundColor(.secondary)
                            Text(String(format: "%+.1f", result.avgDailyChange))
                                .font(.title2).fontWeight(.bold)
                                .foregroundColor(result.avgDailyChange >= 0 ? theme.positiveGreen : theme.negativeRed)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(theme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                        // 风险说明
                        Text(churnDescription(for: result.churnRiskLevel))
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
                    systemImage: "person.2.slash",
                    description: Text(loc(L10n.Premium.noDataRetentionDesc))
                )
            }
        }
        .navigationTitle(loc(L10n.Premium.retentionChurn))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helper Views

    /// 统计卡片：标题 + 数值 + 可选颜色
    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3).fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption).foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    /// 根据流失风险等级返回对应颜色
    private func churnColor(for level: String) -> Color {
        switch level {
        case "None": return theme.positiveGreen
        case "Low": return theme.accentPrimary
        case "Medium": return theme.warningOrange
        default: return theme.negativeRed
        }
    }

    /// 流失风险等级 → 量表档位（0-3，用于 SegmentedScaleView）
    private func churnLevel(for level: String) -> Int {
        switch level {
        case "None": return 0
        case "Low": return 1
        case "Medium": return 2
        default: return 3
        }
    }

    /// 根据流失风险等级返回说明文字（本地化 tip）
    private func churnDescription(for level: String) -> String {
        switch level {
        case "None": return loc(L10n.Premium.tipChurnNone)
        case "Low": return loc(L10n.Premium.tipChurnLow)
        case "Medium": return loc(L10n.Premium.tipChurnMedium)
        default: return loc(L10n.Premium.tipChurnHigh)
        }
    }
}
