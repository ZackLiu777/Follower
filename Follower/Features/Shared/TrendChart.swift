//
//  TrendChart.swift
//  Follower
//
//  Sigma: 固定 Domain + 完美刻度 — 对标 Apple Fitness App 图表。
//

import SwiftUI
import Charts

struct TrendChart: View {
    let dataPoints: [TrendDataPoint]
    let barGradientStart: Color
    let barGradientEnd: Color
    let title: String
    var timeWindow: TimeWindow = .day

    static func barWidth(for count: Int) -> CGFloat {
        if count <= 7 { 28 } else if count <= 12 { 18 } else if count <= 24 { 10 } else { 7 }
    }

    // ── Reference & Domain ──

    private var referenceDate: Date { Date() }
    private let calendar = Calendar.current

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
                    x: .value("Date", point.date),
                    y: .value("Value", point.value),
                    width: .fixed(Self.barWidth(for: dataPoints.count))
                )
                .foregroundStyle(
                    LinearGradient(colors: [barGradientStart, barGradientEnd], startPoint: .top, endPoint: .bottom)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
        .chartXScale(domain: xScaleDomain, range: .plotDimension())
        .chartXAxis {
            switch timeWindow {
            case .day:
                AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                    AxisValueLabel { if let d = value.as(Date.self) { Text("\(calendar.component(.hour, from: d)):00").font(.caption2) } }
                }
            case .week:
                AxisMarks(values: .stride(by: .day, count: 1)) { value in
                    if let d = value.as(Date.self) {
                        AxisValueLabel {
                            Text(d, format: .dateTime.weekday(.abbreviated))
                        }
                    }
                }
            case .month:
                let ms = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate))!
                let ticks = (0..<5).compactMap { calendar.date(byAdding: .day, value: $0 * 7, to: ms) }
                AxisMarks(values: ticks) { value in
                    AxisValueLabel { if let d = value.as(Date.self) { Text("\(calendar.component(.day, from: d))").font(.caption2) } }
                }
            case .year:
                AxisMarks(values: .stride(by: .month, count: 1)) { value in
                    AxisValueLabel { if let d = value.as(Date.self) { Text("\(calendar.component(.month, from: d))").font(.caption2) } }
                }
            }
        }
        .chartYAxis { AxisMarks(position: .trailing) }
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
        TrendDataPoint(date: Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date(), value: Double.random(in: 500...5000))
    }
    TrendChart(dataPoints: sample, barGradientStart: .blue, barGradientEnd: .blue.opacity(0.7), title: "Followers", timeWindow: .week).padding()
}
