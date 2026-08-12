//
//  BestTimeView.swift
//  Follower
//
//  Phi: Premium 详情 — 最佳发帖时间（基于真实 MediaPost 帖子数据）。
//  与「互动热力图」（Event+快照）数据源分离：本页回答「哪个时段发帖互动最好」，
//  UI 采用 Swift Charts 柱状图（24 小时 + 7 天），最佳时段高亮。
//

import SwiftUI
import Charts

/// Premium 详情页：基于 MediaPost 发布时间的互动表现分析
struct BestTimeView: View {
    @Environment(\.theme) private var theme

    /// 最佳发帖时间分析结果（由 BestPostingTimeService 生成）
    let result: BestPostingTimeResult?

    /// 星期标签（Sun-first，与 dayValues 顺序一致）
    private var dayLabels: [String] {
        [loc(L10n.Premium.daySun), loc(L10n.Premium.dayMon), loc(L10n.Premium.dayTue),
         loc(L10n.Premium.dayWed), loc(L10n.Premium.dayThu), loc(L10n.Premium.dayFri),
         loc(L10n.Premium.daySat)]
    }

    /// 最佳发帖时间 UI：Hero 推荐 + 每小时/每星期互动柱状图
    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.backgroundGradientColors,
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                if let result, result.totalPosts > 0 {
                    VStack(alignment: .leading, spacing: 16) {
                        heroCard(result)
                        bubbleMatrixCard(result)
                        dayChartCard(result)
                    }
                    .padding(.vertical)
                } else {
                    ContentUnavailableView(
                        loc(L10n.Premium.noDataBestTime),
                        systemImage: "clock.fill",
                        description: Text(loc(L10n.Premium.noDataBestTimeDesc))
                    )
                    .padding(.top, 80)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(loc(L10n.Premium.bestTimeToPost))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Hero 卡片：最佳时段推荐 + 数据样本说明
    private func heroCard(_ result: BestPostingTimeResult) -> some View {
        VStack(spacing: 4) {
            Text("📅 \(result.peakDescription)").font(.title2).fontWeight(.bold)
            Text("\(String(format: loc(L10n.Premium.basedOnPosts), result.totalPosts)) · "
                 + String(format: loc(L10n.Premium.avgEngagementPerPost),
                          String(format: "%.0f", result.avgEngagementPerPost)))
                .font(.subheadline).foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    /// 互动气泡矩阵卡片：7 行（周日-周六）× 8 列（每 3 小时桶）
    /// 实心圆大小 = 平均互动；颜色深度 = 相对最佳时段的表现；
    /// 外圈半径 = 样本量（帖子数），中心数字 = 样本量 — 防止「1 篇高互动帖」误导最佳时段判断
    private func bubbleMatrixCard(_ result: BestPostingTimeResult) -> some View {
        let bestAvg = result.bestBubble?.avgEngagement ?? 0
        let maxCount = result.matrixCells.map(\.postCount).max() ?? 0

        return VStack(alignment: .leading, spacing: 10) {
            Text(loc(L10n.Premium.bubbleMatrix)).font(.headline)

            // 图例：圆大小与颜色 = 平均互动，数字 = 帖子数
            HStack(spacing: 5) {
                Circle().fill(theme.accentPrimary).frame(width: 8, height: 8)
                Text(loc(L10n.Premium.bubbleLegend))
                    .font(.caption2).foregroundStyle(.secondary)
            }

            // 顶部时段标签（00/03/.../21，每 3 小时一桶）
            HStack(spacing: 6) {
                Color.clear.frame(width: dayLabelWidth, height: 10)
                ForEach(0..<8, id: \.self) { bucket in
                    Text(String(format: "%02d", bucket * 3))
                        .font(.caption2).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // 7 行（Sun-first）
            ForEach(1...7, id: \.self) { weekday in
                HStack(spacing: 6) {
                    Text(dayLabels[weekday - 1])
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(width: dayLabelWidth, alignment: .leading)
                    ForEach(0..<8, id: \.self) { bucket in
                        bubbleCell(result, weekday: weekday, bucket: bucket,
                                   bestAvg: bestAvg, maxCount: maxCount)
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

    /// 星期标签列宽度（与顶部时段标签行对齐）
    private var dayLabelWidth: CGFloat { 36 }

    /// 单个气泡格：实心圆（大小=平均互动、颜色=相对表现）+ 外圈（样本量）+ 中心数字（帖子数）
    private func bubbleCell(_ result: BestPostingTimeResult, weekday: Int, bucket: Int,
                            bestAvg: Double, maxCount: Int) -> some View {
        GeometryReader { geo in
            let cell = result.bubbleCell(weekday: weekday, hourBucket: bucket)
            let maxR = max(8, min(geo.size.width / 2 - 2, 16))
            if let cell, cell.postCount > 0 {
                let perf = CGFloat(bestAvg > 0 ? min(cell.avgEngagement / bestAvg, 1) : 0)
                let fillR = 6 + (maxR - 6) * perf
                let countNorm = CGFloat(maxCount > 0 ? Double(cell.postCount) / Double(maxCount) : 0)
                let ringR = fillR + 2 + (maxR - fillR) * countNorm
                ZStack {
                    Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                        .frame(width: ringR * 2, height: ringR * 2)
                    Circle().fill(theme.accentPrimary.opacity(0.15 + 0.85 * perf))
                        .frame(width: fillR * 2, height: fillR * 2)
                    Text("\(cell.postCount)")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 无样本时段：淡色小点占位，保持矩阵视觉完整
                Circle().fill(Color.secondary.opacity(0.15))
                    .frame(width: 4, height: 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: 38)
    }

    /// 每星期互动柱状图卡片（7 根柱，最佳日高亮）
    /// 渲染配置与 TrendChart.dayChart 同构（Date 连续域 + plotDimension）
    private func dayChartCard(_ result: BestPostingTimeResult) -> some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayWeekday = calendar.component(.weekday, from: today)  // 1=Sun
        // 本周日作为起点，7 根柱按 Sun..Sat 升序排列
        let weekStart = calendar.date(byAdding: .day, value: -(todayWeekday - 1), to: today)!
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        let dayStarts = (1...7).map { calendar.date(byAdding: .day, value: $0 - 1, to: weekStart)! }

        return VStack(alignment: .leading, spacing: 8) {
            Text(loc(L10n.Premium.dailyEngagement)).font(.headline)
            Chart {
                ForEach(1...7, id: \.self) { weekday in
                    BarMark(
                        x: .value("Day", dayStarts[weekday - 1], unit: .day),
                        y: .value("Value", result.dayValue(weekday: weekday)),
                        width: .ratio(0.6)
                    )
                    .foregroundStyle(weekday == result.bestDay
                                     ? theme.accentPrimary
                                     : theme.accentPrimary.opacity(0.25))
                }
            }
            .chartXScale(domain: weekStart...weekEnd, range: .plotDimension(padding: 0))
            .chartYScale(domain: 0...1)
            .chartXAxis {
                AxisMarks(values: dayStarts) { value in
                    if let d = value.as(Date.self) {
                        let weekday = calendar.component(.weekday, from: d)
                        if dayLabels.indices.contains(weekday - 1) {
                            AxisValueLabel {
                                Text(dayLabels[weekday - 1]).font(.caption2)
                            }
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: [0, 0.5, 1]) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.secondary.opacity(0.25))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v * 100))%").font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 150)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}
