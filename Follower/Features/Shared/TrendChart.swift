//
//  TrendChart.swift
//  Follower
//
//  Lambda-2: 竖条柱状图组件。Swift Charts BarMark + 等比宽度 + 渐变填充。
//

import SwiftUI
import Charts

struct TrendChart: View {
    let dataPoints: [TrendDataPoint]
    let barGradientStart: Color
    let barGradientEnd: Color
    let title: String

    static func barWidthRatio(for count: Int) -> Double {
        switch count {
        case ...4:  return 0.90
        case 5...7: return 0.80
        case 8...12: return 0.70
        case 13...24: return 0.60
        default: return 0.50
        }
    }

    private var barWidthRatio: Double { Self.barWidthRatio(for: dataPoints.count) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)

            if dataPoints.isEmpty {
                emptyState
            } else {
                Chart(dataPoints) { point in
                    BarMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value),
                        width: .automatic
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [barGradientStart, barGradientEnd],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5))
                }
                .chartYAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                .frame(height: 200)
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.fill")
                .font(.largeTitle).foregroundColor(.secondary)
            Text(loc(L10n.Trends.noData))
                .font(.subheadline).foregroundColor(.secondary)
            Text(loc(L10n.Trends.noDataHint))
                .font(.caption).foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

#Preview {
    let sample = (0..<30).map { i in
        TrendDataPoint(
            date: Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date(),
            value: Double.random(in: 500...5000)
        )
    }
    TrendChart(
        dataPoints: sample,
        barGradientStart: Color(red: 0.96, green: 0.55, blue: 0.31),
        barGradientEnd: Color(red: 0.82, green: 0.18, blue: 0.49),
        title: "Followers Growth"
    )
    .padding()
}
