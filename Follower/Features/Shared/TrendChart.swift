//
//  TrendChart.swift
//  Follower
//
//  Lambda-2: 自适应柱状图。真实数据抽样 X 轴 + 圆角柱 + 呼吸边距 + Plot 背景。
//

import SwiftUI
import Charts

struct TrendChart: View {
    let dataPoints: [TrendDataPoint]
    let barGradientStart: Color
    let barGradientEnd: Color
    let title: String

    static func barWidth(for count: Int) -> CGFloat {
        if count <= 7 { return 24 }
        else if count <= 20 { return 18 }
        else if count <= 50 { return 14 }
        else { return 10 }
    }

    private var barWidth: CGFloat { Self.barWidth(for: dataPoints.count) }

    private var chartWidth: CGFloat {
        let c = dataPoints.count
        if c <= 12 { return screenW - 48 }
        else if c <= 30 { return CGFloat(c) * 30 }
        else { return CGFloat(c) * 24 }
    }

    private var screenW: CGFloat {
        #if os(iOS)
        UIScreen.main.bounds.width
        #else
        400
        #endif
    }

    private var needsScroll: Bool { dataPoints.count > 12 }

    // ── X-axis: sample from real data ──

    private var xAxisDates: [Date] {
        let c = dataPoints.count
        let step: Int = { if c <= 7 { 1 } else if c <= 20 { 3 } else if c <= 50 { 7 } else { 14 } }()
        return stride(from: 0, to: c, by: step).map { dataPoints[$0].date }
    }

    private func axisLabel(_ d: Date) -> String {
        let f = DateFormatter()
        let c = dataPoints.count
        f.dateFormat = c <= 7 ? "M/d" : (c <= 30 ? "MMMd" : "MMM")
        return f.string(from: d)
    }

    // ── Body ──

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).padding(.horizontal, 8)
            if dataPoints.isEmpty { emptyState }
            else { chartView }
        }
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var chartView: some View {
        let chart = Chart(dataPoints) { point in
            BarMark(x: .value("Date", point.date), y: .value("Value", point.value), width: .fixed(barWidth))
                .foregroundStyle(LinearGradient(colors: [barGradientStart, barGradientEnd], startPoint: .top, endPoint: .bottom))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .opacity(0.92)
        }
        .chartXAxis {
            AxisMarks(values: xAxisDates) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(.gray.opacity(0.2))
                AxisTick(length: 4)
                AxisValueLabel { if let d = value.as(Date.self) { Text(axisLabel(d)).font(.caption2).foregroundStyle(.secondary) } }
            }
        }
        .chartYAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
        .chartXScale(range: .plotDimension(startPadding: 20, endPadding: 20))
        .chartPlotStyle { $0.background(Color.white.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 12)) }

        if needsScroll {
            ScrollView(.horizontal, showsIndicators: false) {
                chart.frame(width: chartWidth, height: 220).padding(.horizontal, 8)
            }
        } else {
            chart.frame(height: 220).padding(.horizontal, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.fill").font(.largeTitle).foregroundColor(.secondary)
            Text(loc(L10n.Trends.noData)).font(.subheadline).foregroundColor(.secondary)
            Text(loc(L10n.Trends.noDataHint)).font(.caption).foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

#Preview {
    TrendChart(
        dataPoints: (0..<90).map { i in
            TrendDataPoint(date: Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date(), value: Double.random(in: 500...5000))
        },
        barGradientStart: Color(red: 0.96, green: 0.55, blue: 0.31),
        barGradientEnd: Color(red: 0.82, green: 0.18, blue: 0.49),
        title: "Followers Growth"
    ).padding()
}
