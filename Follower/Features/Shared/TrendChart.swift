//
//  TrendChart.swift
//  Follower
//
//  Sigma: Cell-Centered Bars + Grid-Boundary Lines — 对标 Apple Fitness App 图表。
//
//  设计原则：
//    1. 柱子放在 cell 中心（如周一 12:00），不放在 cell 边界（周一 00:00）
//    2. 垂直 grid line 画在 cell 边界（如周一 00:00、周二 00:00）
//    3. X 轴标签放在 cell 中心（与柱子对齐）
//    4. 柱宽用 .ratio() 而非 .fixed()，结构性消除边界裁切
//    5. Y 域显式上取整 + 留白，柱顶永远不超顶部 grid line
//

import SwiftUI
import Charts

struct TrendChart: View {
    let dataPoints: [TrendDataPoint]
    let barGradientStart: Color
    let barGradientEnd: Color
    let title: String
    var timeWindow: TimeWindow = .day

    // ── Reference & Domain ──

    private var referenceDate: Date { Date() }
    private let calendar = Calendar.current

    /// 柱子占 cell 宽度的比例。不同窗口不同比例 → 像素宽度自然不同
    /// （周窗口 cell=1天柱最粗，年窗口 cell=1月柱最细）
    private var barRatio: CGFloat {
        switch timeWindow {
        case .day:   return 0.6   // 24 根，留 40% gap
        case .week:  return 0.7   // 7 根，最粗
        case .month: return 0.6   // 28-31 根
        case .year:  return 0.65  // 12 根
        }
    }

    /// 干净的 cell 起止 domain（不再延伸，避免与柱子半宽玩猫鼠游戏）
    private var xScaleDomain: ClosedRange<Date> {
        switch timeWindow {
        case .day:
            let start = calendar.startOfDay(for: referenceDate)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return start...end
        case .week:
            let start = startOfWeek(for: referenceDate)
            let end = calendar.date(byAdding: .day, value: 7, to: start)!
            return start...end
        case .month:
            let comps = calendar.dateComponents([.year, .month], from: referenceDate)
            let start = calendar.date(from: comps)!
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
            return start...end
        case .year:
            let comps = calendar.dateComponents([.year], from: referenceDate)
            let start = calendar.date(from: comps)!
            let end = calendar.date(byAdding: .year, value: 1, to: start)!
            return start...end
        }
    }

    private var xUnit: Calendar.Component {
        switch timeWindow {
        case .day: .hour; case .week, .month: .day; case .year: .month
        }
    }

    /// Y 域：显式上取整 + 15% 留白，柱顶永远在顶部 grid line 之下
    private var yScaleDomain: ClosedRange<Double> {
        let maxValue = dataPoints.map(\.value).max() ?? 0
        guard maxValue > 0 else { return 0...1 }
        let magnitude = pow(10, floor(log10(maxValue)))
        let niceMax = ceil(maxValue * 1.15 / magnitude) * magnitude
        return 0...niceMax
    }

    // ── Body ──

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline).foregroundColor(.secondary).padding(.leading, 4)

            if dataPoints.isEmpty { emptyState }
            else { chartContent }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var chartContent: some View {
        Chart {
            ForEach(dataPoints) { point in
                BarMark(
                    x: .value("Date", point.date, unit: xUnit),
                    y: .value("Value", point.value),
                    width: .ratio(barRatio)
                )
                .foregroundStyle(
                    LinearGradient(colors: [barGradientStart, barGradientEnd], startPoint: .top, endPoint: .bottom)
                )
            }
        }
        .chartXScale(domain: xScaleDomain, range: .plotDimension(padding: 0))
        .chartYScale(domain: yScaleDomain)
        .chartXAxis {
            switch timeWindow {
            case .day:
                // Grid line 在 cell 边界（0, 5, 10, 15, 20, 24h）
                // Label 在 cell 中心（2, 7, 12, 17, 22h）
                let dayStart = calendar.startOfDay(for: referenceDate)
                let boundaries = [0, 5, 10, 15, 20, 24].map {
                    calendar.date(byAdding: .hour, value: $0, to: dayStart)!
                }
                let centers = [2, 7, 12, 17, 22].map {
                    calendar.date(byAdding: .hour, value: $0, to: dayStart)!
                }
                AxisMarks(values: boundaries) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        .foregroundStyle(Color.secondary.opacity(0.25))
                }
                AxisMarks(values: centers) { value in
                    if let d = value.as(Date.self) {
                        AxisValueLabel {
                            Text("\(calendar.component(.hour, from: d)):00").font(.caption2)
                        }
                    }
                }

            case .week:
                let start = startOfWeek(for: referenceDate)
                // Grid line 8 条：Mon 00:00, Tue 00:00, ..., next-Mon 00:00（cell 边界）
                let boundaries = (0...7).map {
                    calendar.date(byAdding: .day, value: $0, to: start)!
                }
                // Label 7 个：Mon 12:00, ..., Sun 12:00（cell 中心，与柱子对齐）
                let centers = (0..<7).map {
                    calendar.date(bySettingHour: 12, minute: 0, second: 0, of:
                        calendar.date(byAdding: .day, value: $0, to: start)!)!
                }
                AxisMarks(values: boundaries) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        .foregroundStyle(Color.secondary.opacity(0.25))
                }
                AxisMarks(values: centers) { value in
                    if let d = value.as(Date.self) {
                        AxisValueLabel {
                            Text(d, format: .dateTime.weekday(.abbreviated)).font(.caption2)
                        }
                    }
                }

            case .month:
                let ms = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate))!
                let daysInMonth = calendar.range(of: .day, in: .month, for: ms)!.count
                // Grid line 在 1, 8, 15, 22, 29, 月末+1（cell 边界）
                let boundaries: [Date] = [0, 7, 14, 21, 28, daysInMonth].compactMap {
                    calendar.date(byAdding: .day, value: $0, to: ms)
                }
                // Label 在 4, 11, 18, 25（cell 中心）
                let centers: [Date] = [3, 10, 17, 24].compactMap {
                    calendar.date(byAdding: .day, value: $0, to: ms)
                }
                AxisMarks(values: boundaries) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        .foregroundStyle(Color.secondary.opacity(0.25))
                }
                AxisMarks(values: centers) { value in
                    if let d = value.as(Date.self) {
                        AxisValueLabel {
                            Text("\(calendar.component(.day, from: d))").font(.caption2)
                        }
                    }
                }

            case .year:
                let ys = calendar.date(from: calendar.dateComponents([.year], from: referenceDate))!
                // Grid line 13 条：1/1, 2/1, ..., 12/1, next-1/1（cell 边界）
                let boundaries = (0...12).map {
                    calendar.date(byAdding: .month, value: $0, to: ys)!
                }
                // Label 12 个：每月 15 号（cell 中心，与柱子对齐）
                let centers = (0..<12).map {
                    calendar.date(byAdding: .day, value: 14, to:
                        calendar.date(byAdding: .month, value: $0, to: ys)!)!
                }
                AxisMarks(values: boundaries) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.secondary.opacity(0.25))
                }
                AxisMarks(values: centers) { value in
                    if let d = value.as(Date.self) {
                        AxisValueLabel {
                            Text("\(calendar.component(.month, from: d))").font(.caption2)
                        }
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.25))
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text(v, format: .number).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(height: 220)
    }

    // ── Empty ──

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.fill").font(.largeTitle).foregroundColor(.secondary)
            Text(loc(L10n.Trends.noData)).font(.subheadline).foregroundColor(.secondary)
            Text(loc(L10n.Trends.noDataHint)).font(.caption).foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func startOfWeek(for date: Date) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday

        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: components) ?? cal.startOfDay(for: date)
    }
}

#Preview {
    let sample = (0..<7).map { i in
        let dayStart = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
        let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart)!
        return TrendDataPoint(date: noon, value: Double.random(in: 500...5000))
    }
    TrendChart(dataPoints: sample, barGradientStart: .blue, barGradientEnd: .blue.opacity(0.7), title: "Followers", timeWindow: .week).padding()
}
