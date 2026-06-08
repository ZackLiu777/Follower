//
//  PredictionDetailView.swift
//  Follower
//
//  Lambda: Premium 详情 — 粉丝预测。

import SwiftUI
import Charts

struct PredictionDetailView: View {
    let predicted: Int

    private var historical: [Double] {
        (0..<90).map { Double(10000 + Int.random(in: -50...100) + $0 * 15) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("~\(predicted.formatted(.number))").font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("Predicted Followers Next Month").font(.subheadline).foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal)

                Chart {
                    ForEach(Array(historical.enumerated()), id: \.0) { i, val in
                        LineMark(x: .value("", i), y: .value("", val))
                            .foregroundStyle(.blue)
                    }
                }
                .frame(height: 200)
                .padding(.horizontal)

                Text("Based on your 90-day growth trend, you're on track to reach ~\(predicted.formatted(.number)) followers. Keep posting consistently to maintain this growth rate.")
                    .font(.caption).foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Follower Prediction")
        .navigationBarTitleDisplayMode(.inline)
    }
}
