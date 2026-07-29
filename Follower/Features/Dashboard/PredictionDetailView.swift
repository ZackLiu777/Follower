//
//  PredictionDetailView.swift
//  Follower
//
//  Lambda: Premium 详情 — 粉丝预测。

import SwiftUI
import Charts

/// Premium 详情页：展示预测粉丝数 + 90 天历史趋势曲线 + 说明文字
struct PredictionDetailView: View {
    @Environment(\.theme) private var theme

    /// 预测下月粉丝数
    let predicted: Int

    let historical: [Double]

    /// 预测数值卡片 + 历史趋势曲线 + 说明文字 UI
    var body: some View {
        ZStack {
            // Theme background gradient
            LinearGradient(
                colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // 预测值 Hero 卡片
                    VStack(spacing: 4) {
                        Text("~\(predicted.formatted(.number))").font(.system(size: 40, weight: .bold, design: .rounded))
                        Text("Predicted Followers Next Month").font(.subheadline).foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)

                    // 90 天历史趋势折线图
                    Chart {
                        ForEach(Array(historical.enumerated()), id: \.0) { i, val in
                            LineMark(x: .value("", i), y: .value("", val))
                                .foregroundStyle(theme.chartLine)
                        }
                    }
                    .frame(height: 200)
                    .padding(.horizontal)

                    // 预测说明文字
                    Text("Based on your 90-day growth trend, you're on track to reach ~\(predicted.formatted(.number)) followers. Keep posting consistently to maintain this growth rate.")
                        .font(.caption).foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(loc(L10n.Premium.followerPrediction))
        .navigationBarTitleDisplayMode(.inline)
    }
}
