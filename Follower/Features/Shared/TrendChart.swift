//
//  TrendChart.swift
//  Follower
//
//  Sigma: 分离式设计 — 日/周/月/年 各自独立的 Chart 实现，互不影响。
//
//  原则：
//    - 每个窗口拥有独立的 Chart、BarMark、domain、axis 配置
//    - 改一个窗口的参数不会影响其他窗口
//    - 外层共享卡片 UI（title、material 背景、圆角）
//

import SwiftUI
import Charts

/// 多时间窗通用柱状图组件 — 日/周/月/年各自独立 Chart 实现，共享外层卡片 UI
struct TrendChart: View {
    let dataPoints: [TrendDataPoint]
    let barGradientStart: Color
    let barGradientEnd: Color
    let title: String
    var timeWindow: TimeWindow = .day

    /// 图表锚点日期，用于计算时间窗起止
    private var referenceDate: Date { Date() }
    private let calendar = Calendar.current
    /// 数据点总数，用于判断空数据等边界条件
    private var n: Int { dataPoints.count }

    // ── Shared Y Domain ──

    /// 自动计算 Y 轴上限，向上取整到美观量级（nice rounding）
    private var yScaleDomain: ClosedRange<Double> {
        let maxValue = dataPoints.map(\.value).max() ?? 0
        guard maxValue > 0 else { return 0...1 }
        let magnitude = pow(10, floor(log10(maxValue)))
        let niceMax = ceil(maxValue * 1.15 / magnitude) * magnitude
        return 0...niceMax
    }

    /// 柱状图渐变填充色，由外部主题决定起止颜色
    private var gradient: LinearGradient {
        LinearGradient(
            colors: [barGradientStart, barGradientEnd],
            startPoint: .top, endPoint: .bottom
        )
    }

    // ── Body ──

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline).foregroundColor(.secondary).padding(.leading, 4)

            if dataPoints.isEmpty { emptyState }
            else {
                switch timeWindow {
                case .day:   dayChart
                case .week:  weekChart
                case .month: monthChart
                case .year:  yearChart
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Day Chart (24h, unit: .hour)

    private var dayChart: some View {
        let dayStart = calendar.startOfDay(for: referenceDate)
        let domainStart = dayStart
        let domainEnd   = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        // Grid line: 0, 5, 10, 15, 20, 24h (cell 边界)
        let boundaries = [0, 5, 10, 15, 20, 24].map { calendar.date(byAdding: .hour, value: $0, to: dayStart)! }
        // Label: 2, 7, 12, 17, 22h (cell 中心)
        let centers = [2, 7, 12, 17, 22].map { calendar.date(byAdding: .hour, value: $0, to: dayStart)! }

        return Chart {
            ForEach(dataPoints) { point in
                BarMark(
                    x: .value("Hour", point.date, unit: .hour),
                    y: .value("Value", point.value),
                    width: .ratio(0.6)
                )
                .foregroundStyle(gradient)
            }
        }
        .chartXScale(domain: domainStart...domainEnd, range: .plotDimension(padding: 0))
        .chartYScale(domain: yScaleDomain)
        .chartXAxis {
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
        }
        .chartYAxis { sharedYAxis }
        .frame(height: 220)
    }

    // MARK: - Week Chart (纯 SwiftUI — 7 天等宽 HStack)

    private var weekChart: some View {
        let yMax = yScaleDomain.upperBound
        let hGridCount = 4
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: LanguageStore.shared.current.rawValue)
        fmt.dateFormat = "EEE"

        return VStack(spacing: 0) {
            // ── Chart area ──
            HStack(alignment: .bottom, spacing: 0) {
                // Y-axis labels
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach((0...hGridCount).reversed(), id: \.self) { i in
                        let val = yMax * Double(i) / Double(hGridCount)
                        Text(formatY(val))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        if i > 0 { Spacer() }
                    }
                }
                .frame(width: 40)
                .padding(.bottom, 2)

                // Plot area
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let cellW = w / 7
                    let barW  = max(1, cellW * 0.6)

                    ZStack(alignment: .topLeading) {
                        // Horizontal grid lines
                        ForEach(0..<hGridCount, id: \.self) { i in
                            let y = h * CGFloat(i + 1) / CGFloat(hGridCount)
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: w, y: y))
                            }
                            .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                            .foregroundColor(.secondary.opacity(0.25))
                        }

                        // Vertical grid lines at day boundaries (8 lines)
                        ForEach(0...7, id: \.self) { i in
                            let x = cellW * CGFloat(i)
                            Path { path in
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: h))
                            }
                            .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                            .foregroundColor(.secondary.opacity(0.25))
                        }

                        // Bars — bottom-aligned in each cell
                        HStack(alignment: .bottom, spacing: 0) {
                            ForEach(dataPoints) { point in
                                let barH = yMax > 0
                                    ? max(point.value > 0 ? 2 : 0,
                                          CGFloat(point.value / yMax) * h)
                                    : 0
                                VStack(spacing: 0) {
                                    Spacer(minLength: 0)
                                    Rectangle()
                                        .fill(gradient)
                                        .frame(width: barW, height: barH)
                                }
                                .frame(maxWidth: .infinity, maxHeight: h)
                            }
                        }
                    }
                }
            }
            .frame(height: 200)

            // ── X-axis labels ──
            HStack(spacing: 0) {
                Color.clear.frame(width: 40)
                ForEach(dataPoints) { point in
                    Text(fmt.string(from: point.date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 20)
        }
    }

    // MARK: - Y Label Formatter (pure SwiftUI 共用)

    private func formatY(_ value: Double) -> String {
        if value >= 10000 { return String(format: "%.0fk", value / 1000) }
        else if value >= 1000 { return String(format: "%.1fk", value / 1000) }
        else if value >= 1 { return String(format: "%.0f", value) }
        return "0"
    }

    // MARK: - Month Chart (28-31 days, unit: .day)

    private var monthChart: some View {
        let comps = calendar.dateComponents([.year, .month], from: referenceDate)
        let ms = calendar.date(from: comps)!
        let domainStart = ms
        let domainEnd   = calendar.date(byAdding: .month, value: 1, to: ms)!
        let daysInMonth = calendar.range(of: .day, in: .month, for: ms)!.count
        // Grid line: 1, 8, 15, 22, 29, end (cell 边界)
        let boundaries = [0, 7, 14, 21, 28, daysInMonth].compactMap {
            calendar.date(byAdding: .day, value: $0, to: ms)
        }
        // Label: 4, 11, 18, 25 (cell 中心)
        let centers = [3, 10, 17, 24].compactMap {
            calendar.date(byAdding: .day, value: $0, to: ms)
        }

        return Chart {
            ForEach(dataPoints) { point in
                BarMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Value", point.value),
                    width: .ratio(0.6)
                )
                .foregroundStyle(gradient)
            }
        }
        .chartXScale(domain: domainStart...domainEnd, range: .plotDimension(padding: 0))
        .chartYScale(domain: yScaleDomain)
        .chartXAxis {
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
        }
        .chartYAxis { sharedYAxis }
        .frame(height: 220)
    }

    // MARK: - Year Chart (12 months, unit: .month)

    private var yearChart: some View {
        let comps = calendar.dateComponents([.year], from: referenceDate)
        let ys = calendar.date(from: comps)!
        let domainStart = ys
        let domainEnd   = calendar.date(byAdding: .year, value: 1, to: ys)!
        // Grid line: 1/1 ... next 1/1，共 13 条 (cell 边界)
        let boundaries = (0...12).map { calendar.date(byAdding: .month, value: $0, to: ys)! }
        // Label: 每月 15 号 (cell 中心)
        let centers = (0..<12).map {
            calendar.date(byAdding: .day, value: 14,
                          to: calendar.date(byAdding: .month, value: $0, to: ys)!)!
        }

        return Chart {
            ForEach(dataPoints) { point in
                BarMark(
                    x: .value("Month", point.date, unit: .month),
                    y: .value("Value", point.value),
                    width: .ratio(0.65)
                )
                .foregroundStyle(gradient)
            }
        }
        .chartXScale(domain: domainStart...domainEnd, range: .plotDimension(padding: 0))
        .chartYScale(domain: yScaleDomain)
        .chartXAxis {
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
        .chartYAxis { sharedYAxis }
        .frame(height: 220)
    }

    // MARK: - Shared Y Axis

    @AxisContentBuilder
    private var sharedYAxis: some AxisContent {
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

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.fill").font(.largeTitle).foregroundColor(.secondary)
            Text(loc(L10n.Trends.noData)).font(.subheadline).foregroundColor(.secondary)
            Text(loc(L10n.Trends.noDataHint)).font(.caption).foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Week Helper

    private func startOfWeek(for date: Date) -> Date {
        var cal = Calendar.current; cal.firstWeekday = 2
        return cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))
            ?? cal.startOfDay(for: date)
    }
}

// MARK: - Previews

/// Day 窗口预览 — 24 小时随机数据
#Preview("Day") {
    let today = Calendar.current.startOfDay(for: Date())
    let sample = (0..<24).map { h in
        TrendDataPoint(
            date: Calendar.current.date(byAdding: .hour, value: h, to: today)!,
            value: Double.random(in: 200...3000)
        )
    }
    TrendChart(dataPoints: sample, barGradientStart: .blue, barGradientEnd: .blue.opacity(0.7), title: "Followers — Day", timeWindow: .day).padding()
}

#Preview("Week") {
    let cal = Calendar.current
    let sample = (0..<7).map { i in
        let dayStart = cal.date(byAdding: .day, value: -i, to: Date())!
        let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart)!
        return TrendDataPoint(date: noon, value: Double.random(in: 500...5000))
    }
    TrendChart(dataPoints: sample, barGradientStart: .blue, barGradientEnd: .blue.opacity(0.7), title: "Followers — Week", timeWindow: .week).padding()
}

#Preview("Month") {
    let cal = Calendar.current
    let comps = cal.dateComponents([.year, .month], from: Date())
    let ms = cal.date(from: comps)!
    let days = cal.range(of: .day, in: .month, for: ms)!.count
    let sample = (0..<days).map { d in
        let date = cal.date(byAdding: .day, value: d, to: ms)!
        return TrendDataPoint(date: date, value: Double.random(in: 300...4000))
    }
    TrendChart(dataPoints: sample, barGradientStart: .blue, barGradientEnd: .blue.opacity(0.7), title: "Followers — Month", timeWindow: .month).padding()
}

#Preview("Year") {
    let cal = Calendar.current
    let ys = cal.date(from: cal.dateComponents([.year], from: Date()))!
    let sample = (0..<12).map { m in
        let date = cal.date(byAdding: .day, value: 14, to: cal.date(byAdding: .month, value: m, to: ys)!)!
        return TrendDataPoint(date: date, value: Double.random(in: 1000...8000))
    }
    TrendChart(dataPoints: sample, barGradientStart: .blue, barGradientEnd: .blue.opacity(0.7), title: "Followers — Year", timeWindow: .year).padding()
}
