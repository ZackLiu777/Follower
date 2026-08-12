//
//  ActivityDetailView.swift
//  Follower
//
//  Gamma: Premium 详情 — 活跃度分析。

import SwiftUI

/// Premium 详情页：展示活跃度分析结果（活跃天数、最佳时段、活动级别）
struct ActivityDetailView: View {
    /// 主题环境
    @Environment(\.theme) private var theme

    /// 活跃度分析结果
    let result: ActivityResult?

    /// 活跃天数进度条 + 级别标签 + 最佳活跃日 UI
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
                        // 活跃级别 Hero 卡片：等级文字 + 量表条
                        VStack(spacing: 10) {
                            Text(result.label)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(activityColor(for: result.label))
                            Text(loc(L10n.Premium.activityLevel)).font(.subheadline).foregroundColor(.secondary)
                            SegmentedScaleView(
                                level: activityLevel(for: result.label),
                                levelColor: activityColor(for: result.label),
                                levelLabel: result.label
                            )
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(theme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal)

                        // 活跃天数比例进度条
                        VStack(spacing: 12) {
                            Text(loc(L10n.Premium.activeDaysRatio)).font(.headline)

                            // 进度条
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(theme.divider)
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(activityColor(for: result.label))
                                        .frame(width: geo.size.width * result.activeDaysRatio)
                                }
                            }
                            .frame(height: 12)
                            .padding(.horizontal, 4)

                            HStack {
                                Text(String(format: loc(L10n.Premium.activeDaysOf), result.activeDays, result.totalDays))
                                    .font(.subheadline).foregroundColor(.secondary)
                                Spacer()
                                Text(String(format: "%.0f%%", result.activeDaysRatio * 100))
                                    .font(.subheadline).fontWeight(.semibold)
                            }
                        }
                        .padding()
                        .background(theme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                        // 平均每日事件数
                        HStack(spacing: 20) {
                            statCard(
                                title: loc(L10n.Premium.avgEventsPerDay),
                                value: String(format: "%.1f", result.avgEventsPerActiveDay),
                                icon: "chart.bar.fill"
                            )
                            statCard(
                                title: loc(L10n.Premium.bestDay),
                                value: dayName(for: result.mostActiveDay),
                                icon: "calendar.badge.clock"
                            )
                        }
                        .padding(.horizontal)

                        // 活跃级别说明
                        Text(activityDescription(for: result.label))
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
                    systemImage: "chart.xyaxis.line",
                    description: Text(loc(L10n.Premium.noDataActivityDesc))
                )
            }
        }
        .navigationTitle(loc(L10n.Premium.activityAnalysis))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helper Views

    /// 统计卡片：标题 + 数值 + SF Symbol 图标
    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(theme.accentPrimary)
            Text(value)
                .font(.title3).fontWeight(.bold)
            Text(title)
                .font(.caption).foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    /// 根据活跃级别返回对应颜色
    private func activityColor(for label: String) -> Color {
        switch label {
        case "Highly Active": return theme.positiveGreen
        case "Active": return theme.accentPrimary
        case "Moderate": return theme.warningOrange
        default: return theme.negativeRed
        }
    }

    /// 活跃级别 → 量表档位（0-3，Highly Active 最高，用于 SegmentedScaleView）
    private func activityLevel(for label: String) -> Int {
        switch label {
        case "Highly Active": return 3
        case "Active": return 2
        case "Moderate": return 1
        default: return 0
        }
    }

    /// 将星期数字转换为可读名称（本地化）
    private func dayName(for weekday: Int?) -> String {
        guard let wd = weekday, (1...7).contains(wd) else { return "N/A" }
        let names = [loc(L10n.Premium.daySun), loc(L10n.Premium.dayMon), loc(L10n.Premium.dayTue),
                     loc(L10n.Premium.dayWed), loc(L10n.Premium.dayThu), loc(L10n.Premium.dayFri),
                     loc(L10n.Premium.daySat)]
        return names[wd - 1]
    }

    /// 根据活跃级别返回说明文字（本地化 tip）
    private func activityDescription(for label: String) -> String {
        switch label {
        case "Highly Active": return loc(L10n.Premium.tipHighlyActive)
        case "Active": return loc(L10n.Premium.tipActive)
        case "Moderate": return loc(L10n.Premium.tipModerate)
        default: return loc(L10n.Premium.tipLowActivity)
        }
    }
}
