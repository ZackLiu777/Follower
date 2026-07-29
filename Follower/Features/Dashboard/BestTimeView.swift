//
//  BestTimeView.swift
//  Follower
//
//  Phi: Premium 详情 — 最佳发帖时间 & 互动热力图（基于真实 Event 数据）。
//

import SwiftUI

/// Premium 详情页：展示最佳发帖时间 + 基于 Event 的 7×24 互动热力图
struct BestTimeView: View {
    @Environment(\.theme) private var theme

    /// 互动热力图结果（由 EngagementHeatmapService 生成）
    let heatmapResult: EngagementHeatmapResult?

    /// 星期标签
    private let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    /// 24 小时数组
    private let hours = Array(0..<24)

    /// 从真实结果构建 7×24 密度矩阵，无数据时回退到随机 mock
    private var heatmap: [[Double]] {
        guard let result = heatmapResult, !result.cells.isEmpty else {
            return Array(repeating: Array(repeating: 0.0, count: 24), count: 7)
        }
        // Calendar weekday: 1=Sun...7=Sat → 映射到 days[0]=Mon
        // 重排为 Mon=0, Tue=1, ..., Sun=6
        var matrix = Array(repeating: Array(repeating: 0.0, count: 24), count: 7)
        for wd in 1...7 {
            let dayIndex = (wd + 5) % 7  // Sun(1)→6, Mon(2)→0, Tue(3)→1...
            for hour in 0..<24 {
                matrix[dayIndex][hour] = result.density(weekday: wd, hour: hour)
            }
        }
        return matrix
    }

    /// 最佳发帖时间 + 热力图 UI
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 推荐最佳时间卡片
                    VStack(spacing: 4) {
                        if let result = heatmapResult, !result.peakDescription.isEmpty, result.peakDescription != "No data" {
                            Text("📅 \(result.peakDescription)").font(.title2).fontWeight(.bold)
                        } else {
                            Text("📅 Wednesday 7 PM").font(.title2).fontWeight(.bold)
                        }
                        Text(loc(L10n.Premium.yourBestPostingTime)).font(.subheadline).foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // 热力图区域
                    VStack(alignment: .leading, spacing: 4) {
                        Text(loc(L10n.Premium.hourlyHeatmap)).font(.headline)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 24), spacing: 1) {
                            ForEach(0..<7, id: \.self) { day in
                                ForEach(0..<24, id: \.self) { hour in
                                    let val = heatmap[day][hour]
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(theme.accentPrimary.opacity(val))
                                        .frame(height: 14)
                                }
                            }
                        }
                        .padding(8)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    // 热力图图例：低到高
                    HStack(spacing: 4) {
                        Text(loc(L10n.Premium.lowEngagement)).font(.caption2).foregroundColor(.secondary)
                        RoundedRectangle(cornerRadius: 1).fill(theme.accentPrimary.opacity(0.1)).frame(width: 12, height: 12)
                        RoundedRectangle(cornerRadius: 1).fill(theme.accentPrimary.opacity(0.5)).frame(width: 12, height: 12)
                        RoundedRectangle(cornerRadius: 1).fill(theme.accentPrimary.opacity(1.0)).frame(width: 12, height: 12)
                        Text(loc(L10n.Premium.highEngagement)).font(.caption2).foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(loc(L10n.Premium.bestTimeToPost))
        .navigationBarTitleDisplayMode(.inline)
    }


}
