//
//  TrendChart.swift
//  Follower
//
//  趋势折线图组件。
//  使用 Swift Charts 绘制历史趋势。
//  支持懒加载数据，避免一次性渲染过多数据点。
//

import SwiftUI
import Charts

struct TrendChart: View {
    let dataPoints: [TrendDataPoint]
    let lineColor: Color
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)

            if dataPoints.isEmpty {
                emptyState
            } else {
                Chart(dataPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(lineColor)

                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [lineColor.opacity(0.2), lineColor.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5))
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 4))
                }
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
            Image(systemName: "chart.line.downtrend.xy")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(loc(L10n.Trends.noData))
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(loc(L10n.Trends.noDataHint))
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
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
        lineColor: .blue,
        title: "Followers Growth"
    )
    .padding()
}
